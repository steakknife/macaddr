require 'socket'

##
# Cross platform MAC address determination.
#
# To return the first MAC address on the system:
#
#   Mac.address
#
# To return an array of all MAC addresses:
#
#   Mac.addresses
module Mac
  extend self

  # @return [String] First hardware address,
  #         in no particular order (varies by system)
  def address
    addresses.first
  end

  # @return [Array<String>] All hardware address,
  #         in no particular order (varies by system)
  def addresses
    iface_macs.values.compact || []
  end

  alias_method :mac_address, :address
  alias_method :addr, :address
  alias_method :addrs, :addresses
 
  # @return [Array<Ifaddr>] Return all interface Ifaddrs
  def ifaddrs
    return unless Socket.respond_to? :getifaddrs
    Socket.getifaddrs.select do |iface|
      iface.addr && iface.addr.pfamily == INTERFACE_PACKET_FAMILY
    end
  end
 
  # @return [Hash<String,[String,nil]>]
  #          all interfaces as keys, values are MAC addresses ((if present)
  def iface_macs
    h = iface_macs_raw.map do |k, v|
      [k, (v != EMPTY_MAC && !v.empty?) ? v : nil]
    end
    Hash[h]
  end

  private
 
  INTERFACE_PACKET_FAMILY = Socket::PF_LINK rescue (Socket::PF_PACKET)
  EMPTY_MAC = '00:00:00:00:00:00'
  HWADDR_REGEX = /hwaddr=([\h:]+)/

  def iface_macs_raw
    if Socket.const_defined? :PF_LINK
      from_getnameinfo
    else
      from_inspect_sockaddr
    end
  end
 
  def from_getnameinfo
    ifaddrs.map do |iface|
      mac = iface.addr.getnameinfo[0]
      [iface.name, mac]
    end
  end
 
  def from_inspect_sockaddr
    ifaddrs.map do |iface|
      mac = iface.addr.inspect_sockaddr[HWADDR_REGEX, 1]
      [iface.name, mac]
    end
  end
end

MacAddr = Macaddr = Mac
