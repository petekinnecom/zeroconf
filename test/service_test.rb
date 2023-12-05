require "helper"

module ZeroConf
  class ServiceTest < Test
    include ZeroConf::Utils

    def test_service_info
      iface = ZeroConf.interfaces.find_all { |x| x.addr.ipv4? }.first

      s = Service.new "_test-mdns._tcp.local.",
        42424,
        "tc-lan-adapter",
        service_interfaces: [iface]

      assert_equal "_test-mdns._tcp.local.", s.service
      assert_equal 42424, s.service_port
      assert_equal "tc-lan-adapter", s.hostname
      assert_equal [iface], s.service_interfaces
      assert_equal "#{s.hostname}.#{s.service}", s.service_name
      assert_equal "#{s.hostname}.local.", s.qualified_host
      assert_equal [""], s.text
    end

    def test_unicast_service_instance_answer
      iface = ZeroConf.interfaces.find_all { |x| x.addr.ipv4? }.first

      s = Service.new "_test-mdns._tcp.local.",
        42424,
        "tc-lan-adapter",
        service_interfaces: [iface], text: ["test=1", "other=value"]

      runner = Thread.new { s.start }

      query = Resolv::DNS::Message.new 0
      query.add_question "tc-lan-adapter._test-mdns._tcp.local.", ZeroConf::SRV

      sock = open_ipv4 iface.addr, 0
      multicast_send sock, query.encode
      res = Resolv::DNS::Message.decode sock.recvfrom(2048).first
      s.stop
      runner.join

      expected = Resolv::DNS::Message.new(0)
      expected.qr = 1
      expected.aa = 1

      expected.add_additional s.qualified_host,
        10,
        Resolv::DNS::Resource::IN::A.new(iface.addr.ip_address)

      expected.add_additional s.service_name,
        10,
        Resolv::DNS::Resource::IN::TXT.new(*s.text)
      expected.add_answer s.service_name, 10, Resolv::DNS::Resource::IN::SRV.new(0, 0, s.service_port, s.qualified_host)
      expected.add_question s.service_name, ZeroConf::MDNS::Announce::IN::SRV

      assert_equal expected, res
    end

    def test_announcement
      ann = "\x00\x00\x84\x00\x00\x00\x00\x01\x00\x00\x00\x03\n_test-mdns\x04_tcp\x05local\x00\x00\f\x00\x01\x00\x00\x00<\x00\x15\x0Etc-lan-adapter\x03lan\xC0\f\xC0-\x00!\x80\x01\x00\x00\x00<\x00 \x00\x00\x00\x00\xA5\xB8\x0Etc-lan-adapter\x03lan\x05local\x00\xC0T\x00\x01\x80\x01\x00\x00\x00<\x00\x04\n\x00\x01\x95\xC0T\x00\x1C\x80\x01\x00\x00\x00<\x00\x10\xFD\xDA\x85k\tL\x00\x00\x10\xF6\x892\xEA\xBB\\H".b
      msg = Resolv::DNS::Message.decode ann
      service = Service.new "_test-mdns._tcp.local.", 42424
      assert_equal msg.encode, service.announcement.encode
    end

    def test_dnssd_unicast_answer
      unicast_answer = "\x00\x00\x84\x00\x00\x01\x00\x01\x00\x00\x00\x00\t_services\a_dns-sd\x04_udp\x05local\x00\x00\f\x80\x01\xC0\f\x00\f\x00\x01\x00\x00\x00\n\x00\x12\n_test-mdns\x04_tcp\xC0#".b
      msg = Resolv::DNS::Message.decode unicast_answer
      service = Service.new "_test-mdns._tcp.local.", 42424, "tc-lan-adapter"
      assert_equal msg.encode, service.dnssd_unicast_answer.encode
    end

    def test_dnssd_multicast_answer
      multicast_answer = "\x00\x00\x84\x00\x00\x00\x00\x01\x00\x00\x00\x00\x09\x5f\x73\x65\x72\x76\x69\x63\x65\x73\x07\x5f\x64\x6e\x73\x2d\x73\x64\x04\x5f\x75\x64\x70\x05\x6c\x6f\x63\x61\x6c\x00\x00\x0c\x00\x01\x00\x00\x00\x3c\x00\x12\x0a\x5f\x74\x65\x73\x74\x2d\x6d\x64\x6e\x73\x04\x5f\x74\x63\x70\xc0\x23"
      msg = Resolv::DNS::Message.decode multicast_answer
      service = Service.new "_test-mdns._tcp.local.", 42424, "tc-lan-adapter"
      assert_equal msg.encode, service.dnssd_multicast_answer.encode
    end

    def test_service_multicast_answer
      multicast_answer = "\x00\x00\x84\x00\x00\x00\x00\x01\x00\x00\x00\x04\x0a\x5f\x74\x65\x73\x74\x2d\x6d\x64\x6e\x73\x04\x5f\x74\x63\x70\x05\x6c\x6f\x63\x61\x6c\x00\x00\x0c\x00\x01\x00\x00\x00\x3c\x00\x11\x0e\x74\x63\x2d\x6c\x61\x6e\x2d\x61\x64\x61\x70\x74\x65\x72\xc0\x0c\xc0\x2d\x00\x21\x00\x01\x00\x00\x00\x3c\x00\x17\x00\x00\x00\x00\xa5\xb8\x0e\x74\x63\x2d\x6c\x61\x6e\x2d\x61\x64\x61\x70\x74\x65\x72\xc0\x1c\xc0\x50\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04\x0a\x00\x01\x95\xc0\x50\x00\x1c\x00\x01\x00\x00\x00\x3c\x00\x10\xfd\xda\x85\x6b\x09\x4c\x00\x00\x10\xf6\x89\x32\xea\xbb\x5c\x48\xc0\x2d\x00\x10\x00\x01\x00\x00\x00\x3c\x00\x13\x06\x74\x65\x73\x74\x3d\x31\x0b\x6f\x74\x68\x65\x72\x3d\x76\x61\x6c\x75\x65".b
      msg = Resolv::DNS::Message.decode multicast_answer
      service = Service.new "_test-mdns._tcp.local.", 42424, "tc-lan-adapter", text: ["test=1", "other=value"]
      assert_equal msg.encode, service.service_multicast_answer.encode
    end

    def test_service_unicast_answer
      iface = ZeroConf.interfaces.find_all { |x| x.addr.ipv4? }.first

      s = Service.new "_test-mdns._tcp.local.",
        42424,
        "tc-lan-adapter",
        service_interfaces: [iface], text: ["test=1", "other=value"]

      runner = Thread.new { s.start }

      query = Resolv::DNS::Message.new 0
      query.add_question "_test-mdns._tcp.local.", ZeroConf::PTR

      sock = open_ipv4 iface.addr, 0
      multicast_send sock, query.encode
      res = Resolv::DNS::Message.decode sock.recvfrom(2048).first
      s.stop
      runner.join

      expected = Resolv::DNS::Message.new(0)
      expected.qr = 1
      expected.aa = 1

      expected.add_additional s.service_name, 10, Resolv::DNS::Resource::IN::SRV.new(0, 0, s.service_port, s.qualified_host)
      expected.add_additional s.qualified_host,
            10,
            Resolv::DNS::Resource::IN::A.new(iface.addr.ip_address)

      expected.add_additional s.service_name,
        10,
        Resolv::DNS::Resource::IN::TXT.new(*s.text)
      expected.add_answer s.service,
        10,
        Resolv::DNS::Resource::IN::PTR.new(Resolv::DNS::Name.create(s.service_name))
      expected.add_question s.service, ZeroConf::PTR

      assert_equal expected, res
    end

    def test_service_instance_multicast_answer
      service_instance_multicast = "\x00\x00\x84\x00\x00\x00\x00\x01\x00\x00\x00\x03\x0e\x74\x63\x2d\x6c\x61\x6e\x2d\x61\x64\x61\x70\x74\x65\x72\x0a\x5f\x74\x65\x73\x74\x2d\x6d\x64\x6e\x73\x04\x5f\x74\x63\x70\x05\x6c\x6f\x63\x61\x6c\x00\x00\x21\x00\x01\x00\x00\x00\x3c\x00\x17\x00\x00\x00\x00\xa5\xb8\x0e\x74\x63\x2d\x6c\x61\x6e\x2d\x61\x64\x61\x70\x74\x65\x72\xc0\x2b\xc0\x42\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04\x0a\x00\x01\x95\xc0\x42\x00\x1c\x00\x01\x00\x00\x00\x3c\x00\x10\xfd\xda\x85\x6b\x09\x4c\x00\x00\x10\xf6\x89\x32\xea\xbb\x5c\x48\xc0\x0c\x00\x10\x00\x01\x00\x00\x00\x3c\x00\x13\x06\x74\x65\x73\x74\x3d\x31\x0b\x6f\x74\x68\x65\x72\x3d\x76\x61\x6c\x75\x65".b
      msg = Resolv::DNS::Message.decode service_instance_multicast
      service = Service.new "_test-mdns._tcp.local.", 42424, "tc-lan-adapter", text: ["test=1", "other=value"]
      assert_equal msg.encode, service.service_instance_multicast_answer.encode
    end
  end
end