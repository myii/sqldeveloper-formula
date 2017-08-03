{%- from 'sqldeveloper/settings.sls' import sqldeveloper with context %}

{#- require a source_url - there may be no default download location for sqldeveloper #}

{%- if sqldeveloper.source_url is defined %}

  {%- set archive_file = sqldeveloper.prefix + '/' + sqldeveloper.source_url.split('/') | last %}

#runtime dependency
sqldeveloper-libaio1:
  pkg.installed:
    {%- if salt['grains.get']('os') == 'Ubuntu' or salt['grains.get']('os') == 'SUSE' %}
    - name: libaio1
    {%- else %}
    - name: libaio
    {%- endif %}

sqldeveloper-install-dir:
  file.directory:
    - names:
      - {{ sqldeveloper.prefix }}
      - {{ sqldeveloper.orahome }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

# curl fails (rc=23) if file exists
sqldeveloper-remove-prev-archive:
  file.absent:
    - name: {{ archive_file }}
    - require:
      - file: sqldeveloper-install-dir

sqldeveloper-download-archive:
  cmd.run:
    - name: curl {{ sqldeveloper.dl_opts }} -o '{{ archive_file }}' '{{ sqldeveloper.source_url }}'
    - require:
      - file: sqldeveloper-remove-prev-archive

  {% if grains['saltversioninfo'] <= [2016, 11, 6] and sqldeveloper.source_hash %}
    # See: https://github.com/saltstack/salt/pull/41914
sqldeveloper-check-archive-hash:
  module.run:
    - name: file.check_hash
    - path: {{ archive_file }}
    - file_hash: {{ sqldeveloper.source_hash }}
    - onchanges:
      - cmd: sqldeveloper-download-archive
    - require_in:
      - archive: sqldeveloper-unpack-archive
  {%- endif %}

sqldeveloper-unpack-archive:
  archive.extracted:
    - name: {{ sqldeveloper.prefix }}
    - source: file://{{ archive_file }}
    - archive_format: {{ sqldeveloper.archive_type }}
  {% if grains['saltversioninfo'] > [2016, 11, 6] and sqldeveloper.source_hash %}
    - source_hash: {{ sqldeveloper.source_hash }}
  {%- endif %}
  {% if grains['saltversioninfo'] < [2016, 11, 0] %}
    - if_missing: {{ sqldeveloper.sqldeveloper_realcmd }}
  {% endif %}
    - onchanges:
      - cmd: sqldeveloper-download-archive

update-sqldeveloper-home-symlink:
  file.symlink:
    - name: {{ sqldeveloper.orahome }}/sqldeveloper
    - target: {{ sqldeveloper.sqldeveloper_real_home }}
    - force: True
    - require:
      - archive: sqldeveloper-unpack-archive
    - onchanges:
      - archive: sqldeveloper-unpack-archive

sqldeveloper-desktop-entry:
  file.managed:
    - source: salt://sqldeveloper/files/sqldeveloper.desktop
    - name: /home/{{ pillar['user'] }}/Desktop/sqldeveloper.desktop
    - user: {{ pillar['user'] }}
  {% if salt['grains.get']('os_family') == 'Suse' or salt['grains.get']('os') == 'SUSE' %}
    - group: users
  {% else %}
    - group: {{ pillar['user'] }}
  {% endif %}
    - mode: 755
    - require:
      - archive: sqldeveloper-unpack-archive
    - onchanges:
      - archive: sqldeveloper-unpack-archive

remove-sqldeveloper-archive:
  file.absent:
    - name: {{ archive_file }}
    - require:
      - archive: sqldeveloper-unpack-archive
      
{%- endif %}
