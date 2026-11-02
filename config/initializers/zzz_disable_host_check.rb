# frozen_string_literal: true

# Rails 6+ blocks requests whose Host header isn't on the config.hosts
# allowlist (DNS-rebinding protection). In development the app is accessed
# through varying hosts — e.g. Docker/Codespaces-forwarded hostnames or
# tunnels — which that allowlist would reject, so clear it entirely there.
# An empty list disables host authorization checks in dev only; production
# and test keep the default protection.
#
# The "zzz_" prefix matters: initializers load alphabetically, and this must
# run after anything else that might repopulate config.hosts.
Rails.application.config.hosts.clear if Rails.env.development?
