# ConoHa WING article redirect test

`htaccess-article-redirects.txt` is the current WordPress `.htaccess` with five NCP article redirects added before the WordPress fallback. The redirects intentionally use temporary HTTP 302 responses until production verification is complete.

1. Upload `htaccess-article-redirects.txt` to the site root without changing the current `.htaccess`.
2. Rename the current `.htaccess` to `.htaccess.wordpress-backup`.
3. Rename `htaccess-article-redirects.txt` to `.htaccess`.
4. Immediately verify the site root, `/soccer/`, and all five legacy article URLs.
5. If a 500 response occurs, rename the new `.htaccess` out of the way and restore `.htaccess.wordpress-backup` to `.htaccess`.

`htaccess-wordpress-original.txt` is a second rollback copy of the original file supplied on 2026-09-15.
