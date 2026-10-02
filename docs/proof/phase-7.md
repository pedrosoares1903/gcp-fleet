# Phase 7 proof — prod, approvals, and rolling updates

Evidence copied from the GitHub Actions logs, because those logs are deleted
after 90 days. Every block below was pasted from a real run; the link next to
it is that run.

prod was destroyed after this was written (`web_count = 0`). The code is still
here: setting `web_count = 2` brings it back.

## 1. prod changes only after someone approves

Run: https://github.com/pedrosoares1903/gcp-fleet/actions/runs/36792836372

`Apply (prod)` waited for review, was approved, then:

```
<paste the "Apply complete!" line>
```

## 2. A rolling update finishes one VM before it starts the next

Run: https://github.com/pedrosoares1903/gcp-fleet/actions/runs/36707976894

```
<paste from Apply (prod): the two "PLAY [Rolling update ...]" lines, the
"Wait until this VM serves the new version" lines, and the PLAY RECAP>
```

## 3. A broken change stops at the first VM

Change: `root /var/www/html;` -> `root /var/www/htm;` in nginx.conf.j2.
`nginx -t` accepts it; nginx then answers 404 to everything.

Run: https://github.com/pedrosoares1903/gcp-fleet/actions/runs/36948293875

```
<paste from Apply (prod): the FAILED - RETRYING lines, the error,
NO MORE HOSTS LEFT, and the PLAY RECAP (prod-web-02 is not in it)>
```

Checked by hand while it was broken:

```
<paste: prod-web-01 -> 404, and the served-by line of prod-web-02>
```

## 4. The fix went through the same path

Revert PR: <link>
Run: <link to the Ansible run of the revert merge>

```
<paste the PLAY RECAP>
```

## Known gap found here

`site.yml` (dev) has no page check: the same broken change left both dev VMs
answering 404 with a green pipeline. See phase 8.
