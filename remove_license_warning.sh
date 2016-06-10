#!/bin/bash -e
# removes annoying over-licenced banner

sed -i '/message << \"service.\"/,/end/{//!d}' /opt/gitlab/embedded/service/gitlab-rails/app/helpers/license_helper.rb
