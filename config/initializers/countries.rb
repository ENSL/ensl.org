# Add EU for legacy support
ISO3166::Data.register(
    alpha2: "EU",
    name: 'Europe',
    translations: {
        en: 'Europe'
    }
)
# Remove countries which don't have their flag represented in flags.png and are not independent according to ISO3166
%w{AQ BQ IM JE CW GG MF}.each {|code| ISO3166::Data.unregister code}