# Reads GPS coordinates from an image's EXIF via libvips (already a project
# dependency). libvips exposes the GPS IFD as fields on the loaded image:
#
#   exif-ifd3-GPSLatitude    "43/1 28/1 281400000/100000000 (...)"
#   exif-ifd3-GPSLatitudeRef "N"
#
# Returns { latitude:, longitude: } in decimal degrees, or nil when the image
# has no usable GPS (PNG, GIF, WebP, or a JPEG without coordinates).
module PostLocation
  DMS_PAIR = %r{([\d.]+)/([\d.]+)}

  def self.from_image(image_path)
    image = Vips::Image.new_from_file(image_path.to_s)

    latitude = read_decimal(image, "exif-ifd3-GPSLatitude", "exif-ifd3-GPSLatitudeRef", "S")
    longitude = read_decimal(image, "exif-ifd3-GPSLongitude", "exif-ifd3-GPSLongitudeRef", "W")

    return nil if latitude.nil? || longitude.nil?

    { latitude: latitude, longitude: longitude }
  rescue Vips::Error
    nil
  end

  def self.read_decimal(image, value_field, ref_field, negative_ref)
    value = image.get(value_field).to_s.split(" (").first
    ref = image.get(ref_field).to_s.split(" (").first

    degrees, minutes, seconds = value.scan(DMS_PAIR).map do |numerator, denominator|
      Rational(numerator.to_i, denominator.to_i)
    end

    return nil unless degrees && minutes && seconds

    decimal = degrees + minutes / 60 + seconds / 3600
    decimal = -decimal if ref.include?(negative_ref)
    decimal.to_f
  rescue Vips::Error
    nil
  end
  private_class_method :read_decimal
end
