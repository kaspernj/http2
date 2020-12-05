# This class holds various classes for error-handeling.
class Http2::Errors
  class BaseError < RuntimeError
    attr_accessor :response
  end

  class Noaccess < BaseError; end

  class Internalserver < BaseError; end

  class Notfound < BaseError; end

  class Badrequest < BaseError; end

  class Unauthorized < BaseError; end

  class UnsupportedMediaType < BaseError; end
end
