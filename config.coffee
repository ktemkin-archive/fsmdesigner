exports.config =
  # See http://brunch.readthedocs.org/en/latest/config.html for documentation.
  files:
    javascripts:
      joinTo:
        'javascripts/fsm.js': /^app.*coffee$/
        'javascripts/vendor.js': /^vendor/
      order:
        before: []

    stylesheets:
      joinTo:
        'stylesheets/fsm.css': /^(app|vendor).*css$/
      order:
        before: []
        after: []

    templates:
      joinTo: 'javascripts/app.js'


  plugins:
    jade:
      options:
        pretty: yes

