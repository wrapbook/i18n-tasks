module I18n::Tasks
  module Command
    module Options
      module Locales
        extend Command::DSL

        cmd_opt :locales, {
            short: :l,
            long:  :locales=,
            desc:  I18n.t('i18n_tasks.cmd.args.desc.locales_filter'),
            conf:  {as: Array, delimiter: /\s*[+:,]\s*/, default: 'all', argument: true, optional: false},
            parse: :parse_locales
        }

        cmd_opt :locale, {
            short: :l,
            long:  :locale=,
            desc:  I18n.t('i18n_tasks.cmd.args.desc.locale'),
            conf:  {default: 'base', argument: true, optional: false},
            parse: :parse_locale
        }

        def parse_locales(opt)
          argv    = Array(opt[:arguments]) + Array(opt[:locales])
          locales = if argv == ['all'] || argv == 'all' || argv.blank?
                      i18n.locales
                    else
                      explode_list_opt(argv).map { |v| v == 'base' ? base_locale : v }
                    end
          locales.each { |locale| validate_locale!(locale) }
          log_verbose "locales for the command are #{locales.inspect}"
          opt[:locales] = locales
        end

        def parse_locale(opt, key = :locale)
          val      = opt[key]
          opt[key] = base_locale if val.blank? || val == 'base'
          opt[key]
        end

        VALID_LOCALE_RE = /\A\w[\w\-_\.]*\z/i

        def validate_locale!(locale)
          raise CommandError.new(I18n.t('i18n_tasks.cmd.errors.invalid_locale', invalid: locale)) if VALID_LOCALE_RE !~ locale
        end
      end
    end
  end
end
