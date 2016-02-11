autoload :RbConfig, 'rbconfig'
autoload :Socket, 'socket'
autoload :Which, 'which'

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
    Socket.getifaddrs.select { |iface| iface.addr && iface.addr.pfamily == INTERFACE_PACKET_FAMILY }
  end
 
  # @return [Hash<String,[String,nil]>]
  #          all interfaces as keys, values are MAC addresses ((if present)
  def iface_macs
    h = iface_macs_raw.map do |k, v|
      v = nil if v.empty? || v !~ EXACT_MAC_REGEX || v =~ EMPTY_MAC
      [k, v]
    end
    Hash[h]
  end

  INTERFACE_PACKET_FAMILY = [:PF_LINK, :PF_PACKET].map { |c| Socket.const_defined?(c) && Socket.const_get(c) }.first
  EMPTY_MAC = /00(?:[^\h]?00){5}(?:[^\h]?00){2}?/.freeze
  HWADDR_REGEX = /hwaddr=([\h:]+)/.freeze
  WINDOWS_REGEX = /win(32|dows|ce)|(ms|cyg|bcc)win|mingw32|djgpp/i.freeze
  WINDOWS = RbConfig::CONFIG["host_os"] =~ WINDOWS_REGEX || RUBY_PLATFORM =~ WINDOWS_REGEX || ENV['OS'] == 'Windows_NT'
  # EUI48 and EUI64
  LOOSE_MAC_REGEX = /\h\h(?:[^\h]\h\h){5}(?:[^\h]\h\h){2}?/.freeze
  EXACT_MAC_REGEX = /\A#{LOOSE_MAC_REGEX}\z/.freeze


  private

  def iface_macs_raw
    if Socket.const_defined? :PF_LINK
      from_getnameinfo
    elsif Socket.const_defined? :PF_PACKET
      from_inspect_sockaddr
    elsif WINDOWS
      for_windows
    else
      from_ifconfig
    end
  end

  
  def for_windows
    from_ipconfig || from_getmac
  end
  
  def clean(arg)
    arg.delete('"') unless arg.nil?
  end
  
  def from_getmac 
    return [] unless Which.which 'getmac'
    %x{getmac /fo CSV /nh}
      .split(/\n/)
      .collect do |interface|
        mac, name = interface.split(/,/)
        name, mac = clean(name), clean(mac)
        [name, mac] if !name.nil?
      end
      .compact
  end

  def filter_mac(line)
    line.gsub(/\h\h(?:-\h\h){12}/, "")                    # delete DHCPv6
      .gsub(/\h{,4}(?::\h{,4}){,31}}/, "")                # delete IPv6
      .gsub(/\d{1,3}(?:\.\d{1,3}){3}/, "")                # delete IPv4
      .gsub(/00(?:-00){3}(?:-\h\h){4}(?:-\h\h){2}?/, "")  # delete Tunnel
      .gsub(/\h{6}(?:-?\h{4}){3}-?\h{12}/, "")            # delete GUIDs/UUIDs
      .scan(LOOSE_MAC_REGEX)                              # mac address(es)
  end

  def from_ifconfig
    name = nil
    %x{ifconfig}
      .split(/\n/)
      .collect do |line|
        if line =~ /\A([^:\s]+):.*\z/
          name = clean($1)
          nil
        elsif line =~ /(?:ether|HWaddr)\s+/
          mac = filter_mac(line)
          [name, mac.first] if !name.nil? && !mac.empty?
        end
      end
      .compact
  end

  def from_ipconfig
    name = nil
    %x{ipconfig /all}
      .split(/\n/)
      .collect do |line|
        if line =~ /\A[^:]+\s*adapter\s*([^:]+):\z/
          name = clean($1)
          nil
        else
          mac = filter_mac(line)
          [name, mac.first] if !name.nil? && !mac.empty?
        end
      end
      .compact
  end
 
  def from_getnameinfo
    ifaddrs.map { |iface| mac = iface.addr.getnameinfo[0]; [iface.name, mac] }
  end
 
  def from_inspect_sockaddr
    ifaddrs.map { |iface| mac = iface.addr.inspect_sockaddr[HWADDR_REGEX, 1]; [iface.name, mac] }
  end
end

MacAddr = Macaddr = Mac
