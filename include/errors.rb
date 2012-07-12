#This class holds various classes for error-handeling.
class Http2::Errors
  #Raised when trying to access something you dont have access to.
  class Noaccess < RuntimeError; end
  
  #Raised when an internal error occurs on the servers side.
  class Internalserver < RuntimeError; end
end