import os
import sys
import re
import libvirt
import argparse
from lxml import etree
from collections import OrderedDict


try:
    from tabulate import tabulate
except ImportError:
    print("Please install tabulate,\n"
          "you can install it using pip like this:\n"
          "$sudo wget https://bootstrap.pypa.io/get-pip.py\n"
          "$sudo python get-pip.py\n"
          "$pip install tabulate\n")
    exit(1)

parser = argparse.ArgumentParser(description="Mapping representor ports"
                                     " to virtual function (vfs)")

parser.add_argument(
    "--port",
    help='interface having the vfs and representor ports',
    type=str,
    required=True)
args = parser.parse_args()


class ExceptionBase(Exception):
    """Base Exception
    To correctly use this class, inherit from it and define
    a 'msg_fmt' property. That msg_fmt will get printf'd
    with the keyword arguments provided to the constructor.
    """
    msg_fmt = ("An unknown exception occurred.")

    def __init__(self, message=None, **kwargs):
        self.kwargs = kwargs

        if not message:
            try:
                message = self.msg_fmt % kwargs
            except Exception:
                # at least get the core message out if something happened
                message = self.msg_fmt

        self.message = message
        super(ExceptionBase, self).__init__(message)

    def format_message(self):
        # NOTE(mrodden): use the first argument to the python Exception object
        # which should be our full NovaException message, (see __init__)
        return self.args[0]


class PciDeviceNotFoundById(ExceptionBase):
    msg_fmt = "PCI device %(id)s not found"


class RepresentorNotFound(ExceptionBase):
    msg_fmt = 'Failed getting representor ports for PF %(ifname)s'


_SRIOV_TOTALVFS = "sriov_totalvfs"

# phys_port_name contains PF## or pf##
PF_RE = re.compile("pf(\d+)", re.IGNORECASE)

# phys_port_name only contains the VF number
INT_RE = re.compile("^(\d+)$")


def parse_pci_address(domain, bus, slot, function):
    if domain is None or bus is None or slot is None or function is None:
        return None
    return ("%s:%s:%s.%s" % (domain[2:], bus[2:], slot[2:], function[2:]))


def get_domains_pcis():
    domains_pcis = dict()
    conn = libvirt.open('qemu:///system')
    if conn is None:
        return None
    domainIDs = conn.listDomainsID()
    for id in domainIDs:
        dom = conn.lookupByID(id)
        if dom is None:
            continue
        name = dom.name()
        raw_xml = dom.XMLDesc(0)
        tree = etree.XML(raw_xml)
        devices = tree.xpath("devices/interface")
        for device in devices:
            if device.attrib.get('type') == 'hostdev':
                address = device.xpath("source/address")[0]
                pci_address = parse_pci_address(address.attrib.get('domain'),
                                                address.attrib.get('bus'),
                                                address.attrib.get('slot'),
                                                address.attrib.get('function'))
                domains_pcis[pci_address] = {"domain_name": name,
                                             "domain_id": str(id)}

    conn.close()
    return domains_pcis


def get_function_by_ifname(ifname):
    """Given the device name, returns the PCI address of a device
    and returns True if the address is in a physical function.
    """
    dev_path = "/sys/class/net/%s/device" % ifname
    sriov_totalvfs = 0
    if os.path.isdir(dev_path):
        try:
            # sriov_totalvfs contains the maximum possible VFs for this PF
            dev_path_file = os.path.join(dev_path, _SRIOV_TOTALVFS)
            with open(dev_path_file, 'r') as fd:
                sriov_totalvfs = int(fd.readline().rstrip())
                return (os.readlink(dev_path).strip("./"),
                        sriov_totalvfs > 0)
        except (IOError, ValueError):
            return os.readlink(dev_path).strip("./"), False
    return None, False


def _parse_pf_number(phys_port_name):
    """Parses phys_port_name and returns PF number or None.
    To determine the PF number of a representor, parse phys_port_name in
    the following sequence and return the first valid match. If none
    match, then the representor is not for a PF.
    """
    match = PF_RE.search(phys_port_name)
    if match:
        return match.group(1)
    return None


def _parse_vf_number(phys_port_name):
    """Parses phys_port_name and returns VF number or None.
    To determine the VF number of a representor, parse phys_port_name
    in the following sequence and return the first valid match. If none
    match, then the representor is not for a VF.
    """
    match = INT_RE.search(phys_port_name)
    if match:
        return match.group(1)
    match = VF_RE.search(phys_port_name)
    if match:
        return match.group(1)
    return None


def get_vf_pci_by_vf_number(ifname, vf_number):
    dev_path = "/sys/class/net/%s/device/virtfn%s" % (ifname, vf_number)
    sriov_totalvfs = 0
    if os.path.isdir(dev_path):
        return os.readlink(dev_path).strip("./")
    return None


def get_representor_port(pf_ifname):
    """Get the representor netdevice which is corresponding to the VF.
    This method gets PF interface name and number of VF. It iterates over all
    the interfaces under the PF location and looks for interface that has the
    VF number in the phys_port_name. That interface is the representor for
    the requested VF.
    """

    domains_pcis = get_domains_pcis()
    pf_path = "/sys/class/net/%s" % pf_ifname
    pf_sw_id_file = os.path.join(pf_path, "phys_switch_id")
    pf_sw_id = None
    try:
        with open(pf_sw_id_file, 'r') as fd:
            pf_sw_id = fd.readline().rstrip()
    except (OSError, IOError):
        raise RepresentorNotFound(ifname=pf_ifname)
    sriov_numvfs_file = "/sys/class/net/%s/device/sriov_numvfs" % pf_ifname
    try:
        with open(sriov_numvfs_file, 'r') as fd:
            sriov_numvfs = fd.readline().rstrip()
    except (OSError, IOError):
        raise RepresentorNotFound(ifname=pf_ifname)

    pf_subsystem_file = os.path.join(pf_path, "subsystem")
    try:
        devices = os.listdir(pf_subsystem_file)
    except (OSError, IOError):
        raise RepresentorNotFound(ifname=pf_ifname)
    rep_list = []
    for device in devices:
        address_str, pf = get_function_by_ifname(device)
        if pf:
            continue
        device_path = "/sys/class/net/%s" % device
        device_sw_id_file = os.path.join(device_path, "phys_switch_id")
        try:
            with open(device_sw_id_file, 'r') as fd:
                device_sw_id = fd.readline().rstrip()
        except (OSError, IOError):
            continue

        if device_sw_id != pf_sw_id:
            continue
        device_port_name_file = (
            os.path.join(device_path, 'phys_port_name'))

        if not os.path.isfile(device_port_name_file):
            continue

        try:
            with open(device_port_name_file, 'r') as fd:
                phys_port_name = fd.readline().rstrip()
        except (OSError, IOError):
            continue
        # If the phys_port_name of the VF-rep is of the format pfXvfY
        # (or vfY@pfX), then match "X" (parent PF's func number) with
        # the PCI func number of pf_ifname.
        rep_parent_pf_func = _parse_pf_number(phys_port_name)
        if rep_parent_pf_func is not None:
                ifname_pf_func = _get_pf_func(pf_ifname)
                if ifname_pf_func is None:
                    continue
                if int(rep_parent_pf_func) != int(ifname_pf_func):
                    continue

        representor_num = _parse_vf_number(phys_port_name)
        vf_port_name_path = os.path.join(pf_path,
                                         'device/virtfn%s/net' % str(
                                             representor_num))
        # Note: representor_num can be 0, referring to VF0
        if representor_num is None:
            continue

        try:
            vf_port_name = os.listdir(vf_port_name_path)[0]
        except (OSError, IOError):
            vf_port_name = ""

        # At this point we're confident we have a representor.
        vf_pci = get_vf_pci_by_vf_number(pf_ifname, representor_num)
        rep_list.append(OrderedDict([
            ("VF NUMBER", int(representor_num)),
            ("REPRESENTOR PORT", device),
            ("VF PORT", vf_port_name),
            ("VF PCI", vf_pci),
            ("PF NAME", pf_ifname),
            ("MACHINE NAME",
             (domains_pcis.get(vf_pci).get("domain_name")
              if domains_pcis.get(vf_pci) else "")),
            ("MACHINE UUID",
             (domains_pcis.get(vf_pci).get("domain_id")
              if domains_pcis.get(vf_pci) else ""))]))
        rep_list.sort(key=lambda x: x.get("VF NUMBER"))
    return rep_list


def main():
    device_name = args.port
    rep_list = get_representor_port(device_name)
    print(tabulate(rep_list, headers="keys"))

if __name__ == '__main__':
    main()
