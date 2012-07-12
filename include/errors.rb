class Http2::Errors
  class Noaccess < RuntimeError; end
  class Internalserver < RuntimeError; end
end