framework 'Cocoa'

class NSData
  def appendString(string)
    appendData(string.dataUsingEncoding NSUTF8StringEncoding)
  end
end

class MultiPart 
  @@types = {".png" => "image/png"}

  def initWithURL(url)
    @request = NSMutableURLRequest.alloc
      .initWithURL(url,
                   cachePolicy: NSURLRequestReloadIgnoringCacheData,
                   timeoutInterval: 20)

    @request.HTTPMethod = "POST"
    
    @boundary = CFUUIDCreateString(nil, CFUUIDCreate(nil));
    contentType = "multipart/form-data; boundary=" + @boundary
    @request.addValue contentType, forHTTPHeaderField:"Content-Type"
    @params = {}
    self
  end

  def request
    body = NSMutableData.data
    @params.each { |key, value|
      body.appendString "--#{@boundary}\r\n"
      if value.kind_of? File
        type = @@types[File.extname(value.path)] or "application/octet-stream"
	body.appendString("Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n" %
                        [key, File.basename(value)])
	body.appendString "Content-Type: #{type}\r\n\r\n"
	body.appendData NSData.dataWithContentsOfFile(value.path)
      else
        body.appendString "Content-Disposition: form-data; name=\"#{key}\"\r\n\r\n"
        body.appendString "#{value}"
      end
      body.appendString "\r\n"
    }
    body.appendString "--#{@boundary}--\r\n"
    body.writeToFile "/tmp/foobar", atomically:false
    @request.HTTPBody = body

    @request
  end

  def []=(key, value)
    @params[key] = value
  end
end
