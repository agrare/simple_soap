require "./simple_soap/*"

class SimpleSoap
  def self.soap_envelope(header_proc : Proc(XML::Builder, Void)? = nil)
    namespaces = {
      "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
      "xmlns:env" => "http://schemas.xmlsoap.org/soap/envelope/",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
    }

    XML.build do |xml|
      xml.element("env:Envelope", namespaces) do
        if header_proc
          xml.element("env:Header") do
            header_proc.call(xml)
          end
        end

        xml.element("env:Body") do
          yield xml
        end
      end
    end
  end

  def self.request(client : HTTP::Client, path, action : String, body : HTTP::Client::BodyType, cookie : String? = nil)
    headers = HTTP::Headers.new
    headers["content-type"] = "text/xml; charset=utf-8"
    headers["SOAPAction"] = action
    headers["cookie"] = cookie if cookie

    response = client.post(path, headers, body)
    raise "HTTP Error" if response.status_code != 200

    xml = XML.parse(response.body)
    node = xml.xpath_node("//soapenv:Body/*", {"soapenv" => "http://schemas.xmlsoap.org/soap/envelope/"})

    {node, response}
  end
end
