# This class holds various classes for error-handeling.
class Http2::Errors
  class Http2error < RuntimeError
    attr_accessor :response
  end

  class Noaccess < Http2error; end
  class Internalserver < Http2error; end
  class Notfound < Http2error; end
  class Badrequest < Http2error; end
  class Unauthorized < Http2error; end
  class UnsupportedMediaType < Http2error; end
end
