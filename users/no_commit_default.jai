/*

Copy this file and rename it to `no_commit.jai`

It won't be versioned in git and will exist only locally.

(good for storing secret keys and making local changes to the config without commiting them)

!!!
When adjusting values, it's best to create your own file and #load "yourfilename.jai" into here.
That way your personal config can be versioned, and going back in time doesn't become a clusterfuck.

*/

//
// DEFAULTS
//

BUILD_ARCANE :: true;
PROFILE_PERFORMANCE :: false;