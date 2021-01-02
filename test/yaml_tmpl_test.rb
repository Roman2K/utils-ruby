require 'minitest/autorun'
require_relative '../utils'

module Utils

class YAMLTmplTest < Minitest::Test
  def test_result
    res = YAMLTmpl.new.result YAML.load <<'EOS'
_vars: {interval: 15m, service: dustat, args: [stats]}
_noop:
  resources:
  - name:
      _eval: '"every-#{interval}"'
      vars: {interval: {_get: interval}}
    type: time
    source:
      _get: interval-source
      default: {interval: {_get: interval}}
  jobs:
  - name: run
    plan:
    - get:
        _eval: '"every-#{interval}"'
        vars: {interval: {_get: interval}}
    - _noop:
        task: ssh-exec
        config:
          _noop:
            inputs:
              - name: ssh-config
            run:
              path: ssh
              args:
                - 'ubuntu@hetax.srv'
          _merge:
            run:
              args:
              - 'docker-compose'
              - 'run'
              - {_get: service}
            _merge:
              run:
                args: {_get: args, default: []}
EOS
    expected = <<-'EOS'
---
resources:
- name: every-15m
  type: time
  source:
    interval: 15m
jobs:
- name: run
  plan:
  - get: every-15m
  - task: ssh-exec
    config:
      inputs:
      - name: ssh-config
      run:
        path: ssh
        args:
        - ubuntu@hetax.srv
        - docker-compose
        - run
        - dustat
        - stats
EOS
    assert_equal(expected, YAML.dump(res))
  end
end

end
