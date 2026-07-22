# frozen_string_literal: true

# Compiles the legacy theme SCSS with Dart Sass. Being migrated to Tailwind
# utility classes; Bourbon/Neat have been fully removed.
Rails.application.config.dartsass.builds = {
  'themes/default/theme.css.scss' => 'themes/default/theme.css',
  'themes/default/errors.css.scss' => 'themes/default/errors.css'
}
