source common.sh

clearProfiles
clearManifests

rm -f $TEST_ROOT/.nix-channels

# Override location of ~/.nix-channels.
export HOME=$TEST_ROOT

# Test add/list/remove.
nix-channel --add http://foo/bar
nix-channel --list | grep -q http://foo/bar
nix-channel --remove http://foo/bar

[ -e $TEST_ROOT/.nix-channels ]
[ "$(cat $TEST_ROOT/.nix-channels)" = '' ]

# Create a channel.
rm -rf $TEST_ROOT/foo
mkdir -p $TEST_ROOT/foo
nix-push --copy $TEST_ROOT/foo $TEST_ROOT/foo/MANIFEST $(nix-store -r $(nix-instantiate dependencies.nix))
rm -rf $TEST_ROOT/nixexprs
mkdir -p $TEST_ROOT/nixexprs
cp config.nix dependencies.nix dependencies.builder*.sh $TEST_ROOT/nixexprs/
ln -s dependencies.nix $TEST_ROOT/nixexprs/default.nix
(cd $TEST_ROOT && tar cv nixexprs) | bzip2 > $TEST_ROOT/foo/nixexprs.tar.bz2

# Test the update action.
nix-channel --add file://$TEST_ROOT/foo
nix-channel --update

# Do a query.
nix-env -qa \* --meta --xml --out-path > $TEST_ROOT/meta.xml
if [ "$xmllint" != false ]; then
    $xmllint --noout $TEST_ROOT/meta.xml || fail "malformed XML"
fi
grep -q 'meta.*description.*Random test package' $TEST_ROOT/meta.xml
grep -q 'item.*attrPath="foo".*name="dependencies"' $TEST_ROOT/meta.xml

# Do an install.
nix-env -i dependencies
[ -e $TEST_ROOT/var/nix/profiles/default/foobar ]
