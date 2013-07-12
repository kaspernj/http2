#This class holds various classes for error-handeling.
class Http2::Errors
  class Http2error
    attr_accessor :response
  end
  
  #Raised when trying to access something you dont have access to.
  class Noaccess; end
  
  #Raised when an internal error occurs on the servers side.
  class Internalserver; end
  
  #Raised when a page is not found.
  class Notfound < Http2error; end
  
  class Badrequest < Http2error; end
end