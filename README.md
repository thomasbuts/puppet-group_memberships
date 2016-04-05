# group_memberships

## Examples
This will make sure that the user john is member of users & wheel
```
group_memberships { 'john':
  ensure => present,
  groups => [ 'users', 'wheel' ],
}
```

This will make sure that the user john is member users & wheel and will purge all other memberships for this user.
```
group_memberships { 'john':
  ensure => present,
  groups => [ 'users', 'wheel' ],
  purge  => true,
}
```
