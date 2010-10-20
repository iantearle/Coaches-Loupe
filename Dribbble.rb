require 'MultiPart'

def urlEncode(params)
  params.map { |key, value|
    [key, value].map { |value| 
      value.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
        .gsub " ", "%20"
    }.join "="
  }.join("&")
end

class DribbbleLogin
  attr_accessor :delegate
  
  def initWithDelegate(delegate)
    @delegate = delegate
    self
  end
  
  def connection(conn, didReceiveResponse:response)
    root = NSURL.URLWithString("http://dribbble.com/")
    if response.URL.absoluteString == root.absoluteString
      cookies = NSHTTPCookie
        .cookiesWithResponseHeaderFields response.allHeaderFields, forURL:root
      NSHTTPCookieStorage.sharedHTTPCookieStorage
        .setCookies cookies, forURL:root, mainDocumentURL:nil
      @delegate.loginSucceeded
    else
      @delegate.loginFailed
    end    
  end

  def connection(conn, didFailWithError:err)
    @delegate.loginFailed
  end
end

class DribbbleUpload
  attr_accessor :delegate
  
  def initWithDelegate(delegate)
    @delegate = delegate
    self
  end
  
#  def connection(connection, willSendRequest:request, redirectResponse:response)
#    NSLog "!!! redirect to %@", request.URL
#  end

  def connection(conn, didReceiveResponse:response)
    NSLog "!!!"
    if response.URL.absoluteString != "http://dribbble.com/shots"
      @delegate.uploadSucceeded response.URL
    else
      @delegate.uploadFailed
    end
  end
  
  def connection(conn, didFailWithError:err)
    @delegate.uploadFailed
  end
end

class Dribbble
  attr_accessor :delegate
  
  def initWithDelegate(delegate)
    @delegate = delegate
    self
  end
  
  def login(username, password)
    params = {"login" => username, "password" => password}

    content = urlEncode(params)

    request = NSMutableURLRequest.alloc
      .initWithURL(NSURL.URLWithString "http://dribbble.com/session",
                   cachePolicy: NSURLRequestReloadIgnoringCacheData,
                   timeoutInterval: 20)
    request.HTTPMethod = "POST"
    data = content.dataUsingEncoding NSASCIIStringEncoding, allowLossyConversion:true
    request.setValue("%d" % data.length, forHTTPHeaderField:"Content-Length")
    request.setValue "application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type"
    request.HTTPBody = data

    loginDelegate = DribbbleLogin.alloc.initWithDelegate self
    loginDelegate.delegate = @delegate
    NSURLConnection.alloc.initWithRequest(request, delegate:loginDelegate)
  end

  def upload(filename)
    multi = MultiPart.alloc.initWithURL(NSURL.URLWithString "http://dribbble.com/shots")
    multi["screenshot[file]"] = File.new(filename)
    request = multi.request

#    request = NSMutableURLRequest.requestWithURL(NSURL.URLWithString "http://dribbble.com/shots")
#    request.HTTPMethod = "POST"

    root = NSURL.URLWithString("http://dribbble.com/")
    cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage.cookiesForURL root
    headers = NSHTTPCookie.requestHeaderFieldsWithCookies cookies

    headers.writeToFile "/dev/stdout", atomically:false

    request.setAllHTTPHeaderFields headers
    request.addValue "http://dribbble.com/shots/new", forHTTPHeaderField: "Referer"

    uploadDelegate = DribbbleUpload.alloc.initWithDelegate self
    uploadDelegate.delegate = @delegate
    NSURLConnection.alloc.initWithRequest(request, delegate:uploadDelegate)
  end
end
