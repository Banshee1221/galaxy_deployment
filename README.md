# Running:

Make sure to change the following variables in `ansible/group_vars/`:

In `all.yml`, set both of the following correctly:

- `admin_ssh_public_key`;
- `ansible_ssh_user`

In `galaxy.yml`, set `admin_users` correctly. Format is comma-separated emails, e.g. `admin_users: 'foo@bar.com,bar@foo.com'`

Download your OpenRC v3 file from the OpenStack dashboard, source it in your terminal and run `terraform apply` in the root directory.