# ConoHa WING article redirect test

`htaccess-article-redirects.txt` is the current WordPress `.htaccess` with five NCP article redirects added before the WordPress fallback. The redirects intentionally use temporary HTTP 302 responses until production verification is complete.

1. Upload `htaccess-article-redirects.txt` to the site root without changing the current `.htaccess`.
2. Rename the current `.htaccess` to `.htaccess.wordpress-backup`.
3. Rename `htaccess-article-redirects.txt` to `.htaccess`.
4. Immediately verify the site root, `/soccer/`, and all five legacy article URLs.
5. If a 500 response occurs, rename the new `.htaccess` out of the way and restore `.htaccess.wordpress-backup` to `.htaccess`.

`htaccess-wordpress-original.txt` is a second rollback copy of the original file supplied on 2026-09-15.

## Static-site cutover test

`htaccess-static-cutover-test.txt` removes the WordPress fallback while retaining the five temporary article redirects. It deliberately avoids `Options`, `Header`, `Require`, and `DirectoryIndex` directives because the production server already serves `index.html` correctly without them.

1. Keep all WordPress files in place during this test.
2. Upload `htaccess-static-cutover-test.txt` to the site root.
3. Rename the active `.htaccess` to `.htaccess.wordpress-backup-20260916`.
4. Rename `htaccess-static-cutover-test.txt` to `.htaccess`.
5. Immediately verify the root, `/soccer/`, `/food/`, the listing pages, all article pages, and the five old article URLs.
6. On any 500 response, rename the test file out of the way and restore `.htaccess.wordpress-backup-20260916` to `.htaccess`.

Do not delete or move WordPress files until the cutover test passes.
