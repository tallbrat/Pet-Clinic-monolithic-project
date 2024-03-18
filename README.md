# Pet-Clinic-monolithic-project

## Anible Vault

#### Ansible vault file
Initially create a file with all the required credentials
```
mysql_root_password: "your_root_password"
mysql_user_password: "your_user_password"
```
#### Paste the vault files password in a file
```
touch ~/.ansible-key
```
And paste the password of the vault file in this file
Change the files pemission
```
chmod 600 ~/.ansible-key
```
#### To encrypt the vault file
```
ansible-vault --vault-password-file ~/.ansible-key <path where you have the vault file>
```
### To use the vault file when running the playbook
```
ansible-playbook -i inventory.ini --vault-password-file ~/.ansible-key --extra-vars "@<ansible-secret-file>" <playbook-file>
```
`@` prefix to load variables from a file.

## Reverse Proxy
In the reverse-proxy.conf file replace http://localhost:8080; -> `localhost` with the db-servers private IP.