require "./simple_soap/*"
require "http/client"

class SimpleSoap
  property cookie : String?
  getter host : String
  getter path : String
  getter port : Int32
  getter read_timeout : Int32
  getter connect_timeout : Int32

  @http : HTTP::Client?

  def initialize(@host, @port, @path, @cookie = nil, @read_timeout = 1000000, @connect_timeout = 60)
    @http = nil
    restart_http
  end

  def close
    @http.try &.close rescue IOError
  end

  def http : HTTP::Client
    @http.not_nil!
  end

  def restart_http
    begin
      @http.try &.close
    rescue ex
      puts "WARNING: Ignoring exception: #{ex.message}"
      puts ex.backtrace.join("\n")
    end

    context = OpenSSL::SSL::Context::Client.insecure
    new_http = HTTP::Client.new(host, port, context)
    new_http.read_timeout = read_timeout
    new_http.connect_timeout = connect_timeout

    @http = new_http
  end

  def soap_envelope(body, header = nil)
    namespaces = {
      "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
      "xmlns:env" => "http://schemas.xmlsoap.org/soap/envelope/",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
    }

    XML.build do |xml|
      xml.element("env:Envelope", namespaces) do
        if header
          xml.element("env:Header") do
            header.call(xml)
          end
        end

        xml.element("env:Body") do
          body.call(xml)
        end
      end
    end
  end

  def request(action, body)
    headers = HTTP::Headers.new
    headers["content-type"] = "text/xml; charset=utf-8"
    headers["SOAPAction"] = action
    if cookie = @cookie
      headers["cookie"] = cookie
    end

    begin
      response = http.post(path, headers, body)
    rescue ex
      restart_http
      raise ex
    end

    raise "Got HTTP 503: Service unavailable" if response.status_code == 503

    self.cookie = response.headers["set-cookie"] if response.headers.has_key?("set-cookie")

    xml = XML.parse(response.body)
    node = xml.xpath_node("//soapenv:Body/*", {"soapenv" => "http://schemas.xmlsoap.org/soap/envelope/"})

    [node, response.body.size]
  end
end
