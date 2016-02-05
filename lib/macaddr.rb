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
    return [] if !Socket.respond_to?(:getifaddrs) || INTERFACE_PACKET_FAMILY.nil?
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

  # private
 
  INTERFACE_PACKET_FAMILY = Socket.const_defined?(:PF_LINK) ? Socket::PF_LINK : 
    Socket.const_defined?(:PF_PACKET) ? Socket::PF_PACKET : nil
  EMPTY_MAC = '00:00:00:00:00:00'
  HWADDR_REGEX = /hwaddr=([\h:]+)/
  PLATFORM = RUBY_PLATFORM.downcase
  WINDOWS = (PLATFORM =~ /mingw|mswin/)

  def iface_macs_raw
    if Socket.const_defined? :PF_LINK
      from_getnameinfo
    elsif Socket.const_defined? :PF_PACKET
      from_inspect_sockaddr
    else 
      (WINDOWS ? for_windows : from_ifconfig)
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
  
  def for_windows
    (%x{where getmac}).empty? ? from_ipconfig : from_getmac
  end
  
  def clean arg
    arg.gsub(/\"/,'')
  end
  
  def from_getmac 
    getmac = %x{getmac /fo CSV /nh}
    interfaces = getmac.split(/\n/)
    interfaces.collect do |interface| 
      mac,name = interface.split(/,/)
      [clean(name),clean(mac)]
    end
  end
  
  # untested and stolen from http://sketchucation.com/forums/viewtopic.php?f=180&t=55422#p504017
  def from_ipconfig_or_ifconfig    
    iptxt = %x{#{WINDOWS ? 'ipconfig /all' : 'ifconfig'}}
    ## delete DHCPv6 :
    iptxt.gsub!(/..\-..\-..\-..\-..\-..\-..\-..\-..\-..\-..\-..\-..\-../,"") 
    # delete Tunnel :
    iptxt.gsub!("00-00-00-00-","")
    ## create array with all the physical adresses :
    iptxt.scan(/..\-..\-..\-..\-..\-../).collect do |mac| 
      ["ignore", mac]
    end
  end  
  alias_method :from_ipconfig, :from_ipconfig_or_ifconfig
  alias_method :from_ifconfig, :from_ipconfig_or_ifconfig
  
end

MacAddr = Macaddr = Mac
