---
title: Git Tips
description: >
  A collection of useful git tips for all levels of experience.
summary: >
  This is a collection of useful git tips I've accumulated over the years. It
  should serve audiences of all levels and includes git-related tips like LFS,
  encrypted files, encrypted repositories, etc.
date: 2024-06-28
tags: ["coding", "git"]
author: ["Marco Paganini"]
draft: false
---

# Git tips

## Disclaimer

Most of these notes were taken late at night and in a hurry, so errors may exist.
As usual, `git status` is your friend and will show you the status of your repository
and common commands you may need to use.

## Setup

Before *anything* else, make sure to setup your email and name. This will
appear on every commit:

```bash
git config --global user.name "Firstname Lastname"
git config --global user.email "youremail@domain.com"
```

If using on a directory where we don't want to see every file not under git
control when running git status:

```bash
git config [--global]  status.showUntrackedFiles no
```

Create a handy dandy "git graph" command (`git g`):

```bash
git config --global --add alias.g "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) %
C(auto)%d%C(reset) %s %C(dim white)- %an (%ar)' --all"
```

## Creating a new repo

* Create a .git directory in the current repository:

```bash
git init [directory]
```

* Create a bare repository in a file, suitable for external use. By convention,
  bare directories always end up in .git. Bare repositories don't have a
  working directory, so it's impossible to commit changes to them. All central
  repositories should be created with the `--bare` command line option.  More
  detailed explanation: https://mijingo.com/blog/what-is-a-bare-git-repository

```bash
git init --bare <directory.git>
```

## Branching & Merging

* Switch to branch _branch_: `git checkout <branch>`
* Create a branch named _branch_, optionally at [commit_number]: `git checkout -b <branch> [commit_number]`
* Create a branch named _branch_ tracking _remote branch_: `git checkout -b <branch> <remote branch>`
  * E.g.: `git checkout -b foo origin devel`
* List branches: `git branch`
* List all branches (including remote): `git branch -a`
* List remote branches: `git branch -r`
* Remove remote tracking branch: `git branch -r -d <branch>`
* Delete branch _remote/branch_: `git push <remote> --delete <branch>`
  * E.g.: `git push origin --delete foobar`
* List details about branches: `git branch -v`
* Remove branch locally: `git branch -d <branch>`
* Remove remote branch: `git push <remote> --delete <branch>`
* Create a local branch _branch_ pointing to the current HEAD, but don't switch to it.: `git branch <branch>`
* Create a local branch _branch_ pointing to origin/dev: `git branch <branch> --track origin/dev`
* The the tracking branch of _branch_ to origin/foo. Set tracking repo of current branch if [branch] is ommitted.: `git branch --set-upstream-to=origin/foo [branch]`
* Merge change: `git merge <branch>`
  * git mergetool:  https://gist.github.com/karenyyng/f19ff75c60f18b4b8149

### Checking out a remote repo into a local branch (Patching a PR, manual merge)

Create a new branch and pull the remote repo into it.

```bash
git checkout -b <remote-branch-name> master
git pull https://github.com/<user>/<repo> <remote-branch-name>
```

Merge the changes:

```bash
git checkout master
git merge --no-ff <remote-branch-name>   # Use --ff-only or rebase if preferred.
git push origin master
```

## Pushing Changes

* Push current branch to remote branch origin/branchname (creates remote branch if necessary).: `git push origin branchname`
* Promote current development branch to master on origin.: `git push origin origin/development:master`

## Diffs, logs & status

* Perform manual changes after a git merge, if needed.: `git mergetool -t vimdiff`
* Simple one line format log: `git log --oneline`
* Diff the current HEAD with the previous version: `git diff HEAD^ HEAD`
* Diff a given remote/branch with HEAD.: `git diff <remote>/<branch> HEAD`
* Diff index with HEAD.: `git diff --cached`
* See all delete operations affecting "filename": `git log --diff-filter=D -- filename`
  * To restore the file: `git checkout -r <commit#>~1 -- filename"`

## Tagging

* Show all tags (same as git tag -l): `git tag`
* Create a lightweight tag named foo: `git tag foo`
* Create a regular tag named foo, with the specified message.: `git tag -a foo -m "This is the tag foo"`
* Create a tag named foo, at commit 9fceb02: `git tag -a foo 9fceb02`
* Push tag foobar to origin.: `git push origin foobar`
* Push all tags to origin: `git push origin --tags`
* Checks out the repo at the tag version (will create a detached head, create a new branch from this head to work on this tag.): `git checkout supertag_foo`
* Delete local tag: `git tag -d tagname`
* Delete remote tag: `git push --delete origin tagname`
* Push a single tag: `git push origin :refs/tags/<tagname>`
* Attach a tag to a commit id: `git tag <tagname> <commitId>`
* Delete local and remote tag, retag a given tag at a commit id.: `git push origin <tagname>`

**Important Note**: Tags won't be pushed without the explicit tag name or the --tags flag.

## Submodules

* Add a submodule to the system (file .gitmodules created): `git submodule add <submodule_repo_url>`
* Initialize submodules -- copies submodule name and urls from .gitmodules to .git/config.: `git submodule init`
* Clone a module with submodules: `git clone --recursive`
* Recursively update submodules. Specify `--init` to init and update in one step.: `git submodule update --recursive [--init]`
* Update the submodule itself to the newest commit from the submodule's upstream. Using git status on the project directory after that will show "modified: _subproject_name_ (new commits)". A regular git add/commit should follow.: `cd submodule_dir; git pull; cd project_dir`
* Revert submodule state to the submitted one.: `git submodule update --init`
*	Remove a submodule:

```bash
  git submodule deinit <path_to_submodule>
  git rm <path_to_submodule>
  git commit -m "Removed submodule."
  rm -rf .git/modules/<path_to_submodule>
```

## Commiting, resetting & rebasing

* Commit staged files.: `git commit`
* Commit all changed files.: `git commit -a`
* Verbose. Show a diff during commit message edit.: `git commit -v`
* Fix the last commit message.: `git commit --amend`
* Squashes the last four commits into one, interactively. After this command, use git push --force if one of the rebased changes was already pushed. An interactive editor will open to decide what to do with each commit. Changing pick to squash means this commit will be merged with the commit *above* it (note that git lists the commit in chronological order, so the earlier commits are at the top of the list.): `git rebase -i HEAD~4`

**Note**: The number after head (n) means N commits will be affected. Just
removing the commit from the list of commits later means it will be discarded!
It's also possible to give a commit#. In this case, all commits from that point
will be included.

Use "drop" to drop an unwanted commit. Use the "--onto branch" keyword to do
all the interactive rebase changes and then rebase on top of another commit in
one operation.

E.g.: Remove one of he commits and rebase on top of upstream/master

```bash
#  Mark the commit to be removed as "drop"
git rebase -i HEAD~4 --onto upstream/master
```

* Resets the repo to commit#: `git reset --hard <commit#>`
* Undo the last commit. Leave changes as changed files, ready for editing and a new commit.: `git reset HEAD~`
* Same as above, but leaves files staged.: `git reset --soft HEAD~`
* Reset a particular file to HEAD. Useful to remove files from the staged area or when unwinding files from a previous git reset --soft (removing unwanted changes.): `git reset HEAD /path/to/unwanted/file`

## Miscellaneous

* Show all remotes: `git remote -v`
* Show one particular remote. E.g.: git remote show origin: `git remote show <remote>`
* Set remote URL (use --push for push URL) to a given url.: `git remote set-url [--push] <remote> <url>`
  * E.g.: `git remote set-url --push origin git@github.com:foouser/reponame.git`
* Show all files in repo: `git ls-files`
* Show reflog (updates to the tip of branches) information. It's possible to undo steps by using "git reset" on one of the HEADs presented.: `git reflog`
* Cherry Picking:

```bash
git show remote --oneline

aaaaaa foo change HEAD
bbbbbb bar change
cccccc meh change
```

We want to remove bbbbbb:

```bash
git reset cccccc --hard
git cherrypick -n aaaaaa
git status
```

Commit and push as usual.

## Fully encrypted repos using git-remote-gcrypt.

Reference: https://embeddedartistry.com/blog/2018/03/15/safely-storing-secrets-in-git/

* Install git-remote-gcrypt with `apt-get install git-remote-gcrypt`.
* Important: Must have `GPG_TTY` set correctly with `export GPG_TTY=$(tty)`, or
  pinentry will barf.
* Sample usage:

```bash
git remote add origin gcrypt::git@github.com:user/reponame.git
git push origin master
```

**Important**: EVERY PUSH has `--force` implied! Make sure to use git pull first!!!

Note on:

```bash
gcrypt: Repository not found: git@bitbucket.org:mpaganini/crypto-edgerouter.git
gcrypt: ..but repository ID is set. Aborting.
```

This happens when the initial repo push fails. We end up with a push ID but the
repo does not have it. In this case, just remove the gcrypt-id of this repo
with:

```bash
git config --unset remote.origin.gcrypt-id
```

Real life example for /etc:

```bash
# git remote -v
origin  gcrypt::git@github.com:marcopaganini/crypto.git (fetch)
origin  gcrypt::git@github.com:marcopaganini/crypto.git (push)
```

## Partially (or fully) encrypted repos using git-crypt

### Creating a new repo

Reference: `man git-crypt`.

With this solution, we can have some (or all) files encrypted in the repo. It
has the advantage of not requiring a "--force" when pushing and accounting for
times correctly. The downside is that the names of the files remain visible.

* `apt-get install git-crypt`
* In the repo, `git-crypt init`
* Add the user with `git-crypt add-gpg-user gpg_key_id`. This will create the
  `.git-crypt` directory with the keys.
* Create a `.gitattributes` file indicating which files will be encrypted. E.g:

```bash
file_to_encrypt filter=git-crypt diff=git-crypt
*.key filter=git-crypt diff=git-crypt
```

To encrypt all files (except .gitattributes, naturally):

```bash
* filter=git-crypt diff=git-crypt
.gitattributes !filter !diff
```

Add and commit this file.

Run a `git-crypt status` and make sure that the required files are encrypted correctly.'

From this point on, git push will store the files encrypted on the remote.

When using a cloned repo, it's important to use `git-crypt unlock` first.

IMPORTANT: Files added *before* `git-crypt init` remain unencrypted. `git-crypt status --fix`
can fix the current commit, but not the history.

### Using an existing repo

Sample commands:

```bash
git@github.com:marcopaganini/crypto.git
cd cryptorepo
git-crypt unlock
```

## Using git-LFS

Installation is simple:

```bash
apt-get install git-lfs
git lfs install --local --skip-smudge
```

**Note**: to initialize a repo, **always** use `git lfs install --local
--skip-smudge`. Using the smudge filter will make everything slower, but
without it, a manual `git lfs-pull` is required every time we want to update
the git-lfs files.

* To add files to be tracked: `git lfs track glob` (E.g.: `git lfs track *.ttf`)
* `git lfs pull` will bring the files.

To Uninstall:

* Remove the files from git-lfs control with `git lfs untrack glob`. This will remove the
  `.gitattributes` file from the directory where they live.
* Commit the changes.
* Remove the previously tracked files (with `rm`, **not** `git rm`).
* Run `git checkout .`. This will bring the original pointer files. It's also possible to
  delete the files with `git rm` or `git rm --cached` (if we want to keep the files.)
* Use `git rm` to remove the pointer files.
* Run `git lfs uninstall --worktree` to remove git-lfs from the local repository config.

**Note**: `git-lfs ls-files` will show all LFS "controlled" files until the repo is re-created.

## Simple github workflow

```bash
git clone git@github.com/marcopaganini/repo <-- checks out the forked repo
cd repo
git branch -vv (shows the branches)
git checkout -b dev (creates a branch dev, without tracking)
```

Before every change:

* Update all remotes: `git remote update`
* Create a working repo: `git checkout -b dev`
* Reset the working repo to upstream: `git reset upstream/master --hard`
  * Also possible to pull/rebase directly from dev: `git pull -r upstream master`
* Do the changes, `git add`, `git commit`.
* When ready to submit: `git pull -r upstream master` (making sure we're on top of head).
* `git push origin dev`
* Go to https://github.com and open a PR (or use `gh pr create`)

In case of changes:
* Repeat edits, commit, push
* `git pull -r upstream master`
* `git push origin dev --force` (--force may be needed or not, depending on the situation).

It is also possible to use a regular commit instead of rebase, and rebase on
github at merge time. This makes it somewhat easier to have simultaneous
development branches, but creates a non-linear history on the repo.

## Tip: Storing images in github

The idea is to create a new branch with no commits (--orphan) and store the
images here. They can be referenced directly from markdown on the main branch.
In a nutshell:

```bash
git checkout --orphan assets  # Start a new branch from nothing.
git rm -rf .                  # Remove everything from this branch.
<copy image in>
git add; git commit
git push origin assets
git checkout master
```

To refer to this file, use (in the master branch): `![Image](../assets/file.png?raw=true)`

* Source: https://gist.github.com/joncardasis/e6494afd538a400722545163eb2e1fa5

## Daisy Chained changes using github

Taken from: https://graysonkoonce.com/stacked-pull-requests-keeping-github-diffs-small/

The idea is to have multiple pending PRs, one depending on the previous one,
with only the diffs to the previous one. This only works if using branches on
the same repository where the final changes are to be merged. Basic idea:

### Create a branch named foo-part1 with the first part of our changes.

```bash
git checkout -b foo-part1
<hack away...>
git commit -am 'Changes, part 1'
git push origin foo-part1
hub pull-request  # This will create a PR from foo-part1 -> master
```

### Create a second branch names foo-part1 with the second part of changes.

```bash
git checkout -b foo-part2
<hack away...>
git commit -am 'Changes, part 2'
git push origin foo-part2
hub pull-request -b foo-part1  # Notice how the base is the previous branch!
```

Repeat this as many times as needed.

If a change is required in one of the PRs, don't forget to merge (not rebase)
the change to the upper ones. E.g.: Change on part2 must be merged in part3:

```bash
git checkout foo-part2
git merge foo-part2
git commit...
git push origin-part2
```

Once the PRs have been approved, squash/merge them from the top down. The first
one can be rebased into master.

1. squash/merge foo-part2 into foo-part1
1. squash/rebase foo-part1 into master

Remove the branches to keep the repo clean, if that's desirable.  Interesting
discussion on git merge & git rebase
http://stackoverflow.com/questions/6406762/why-am-i-merging-remote-tracking-branch-origin-develop-into-develop

And...

https://www.derekgourlay.com/blog/git-when-to-merge-vs-when-to-rebase/

## Workflow from repo creation to use:

```bash
$ git init --bare /tmp/foo.git
Initialized empty Git repository in /tmp/foo.git/
$ mkdir /tmp/client
$ cd /tmp/client
$ git clone ssh://<host>:/tmp/foo.git .
Cloning into '.'...
warning: You appear to have cloned an empty repository.
Checking connectivity... done.
$ git remote show origin
* remote origin
  Fetch URL: ssh://localhost:/tmp/foo.git
  Push  URL: ssh://localhost:/tmp/foo.git
  HEAD branch: (unknown)
  Local branch configured for 'git pull':
    master merges with remote master
$ echo haha >README
$ git add README
$ git status
On branch master
Initial commit

Changes to be committed:
  (use "git rm --cached <file>..." to unstage)
        new file:   README

Untracked files not listed (use -u option to show untracked files)
$ git commit -m "Initial import."
[master (root-commit) 18fb1b9] Initial import.
 1 file changed, 1 insertion(+)
 create mode 100644 README
$ git push origin master
Counting objects: 3, done.
Writing objects: 100% (3/3), 217 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To ssh://localhost:/tmp/foo.git
 * [new branch]      master -> master
$ git branch -a
* master
  remotes/origin/master
```

## Changing author info on an existing repo

https://help.github.com/articles/changing-author-info/

## Removing all history for deleted files

This answer seems to be the best:
  * http://stackoverflow.com/questions/17901588/new-repo-with-copied-history-of-only-currently-tracked-files/17909526#17909526

## Delete everything and restore what you want

Rather than delete this-list-of-files one at a time, do the almost-opposite,
delete everything and just restore the files you want to keep:

```bash
git checkout master
git ls-files > keep-these.txt
git filter-branch --force --index-filter \
  "git rm --ignore-unmatch --cached -qr . ; cat $PWD/keep-these.txt | xargs git reset -q \$GIT_COMMIT --" \
  --prune-empty --tag-name-filter cat -- --all
```

### Cleanup steps

Once the whole process has finished, then cleanup:

```bash
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now
# optional extra gc. Slow and may not further-reduce the repo size
git gc --aggressive --prune=now
```

## Removing a large file from the repository

http://goo.gl/J9aOP

Comparing the repository size before and after, should indicate a sizable
reduction, and of course only commits that touch the kept files, plus merge
commits - even if empty (because that's how --prune-empty works), will be in
the history.

Copying one directory to another repo, keeping history:

```bash
git clone foo
cd foo
git filter-branch --subdirectory-filter directory_to_keep -- --all
git remote -v
# (confirm old origin, then...)
git remote set-url origin <remote_url_origin.git>
git remote -v
# (make sure all is fine, then...)
git push origin
```

Another solution from: http://goo.gl/VsMAc

Make a copy of repository A so you can mess with it without worrying about
mistakes too much.  It’s also a good idea to delete the link to the original
repository to avoid accidentally making any remote changes (line 3).  Line 4 is
the critical step here.  It goes through your history and files, removing
anything that is not in directory 1.  The result is the contents of directory 1
spewed out into to the base of repository A.  You probably want to import these
files into repository B within a directory, so move them into one now (lines
5/6). Commit your changes and we’re ready to merge these files into the new
repository.

```bash
git clone <git repository A url>
cd <git repository A directory>
git remote rm origin
git filter-branch --subdirectory-filter <directory 1> -- --all
mkdir <directory 1>
mv * <directory 1>
git add .
git commit
```

Make a copy of repository B if you don’t have one already.  On line 3, you’ll
create a remote connection to repository A as a branch in repository B.  Then
simply pull from this branch (containing only the directory you want to move)
into repository B.  The pull copies both files and history.  Note: You can use
a merge instead of a pull, but pull worked better for me. Finally, you probably
want to clean up a bit by removing the remote connection to repository A.
Commit and you’re all set.

```bash
git clone <git repository B url>
cd <git repository B directory>
git remote add repo-A-branch <git repository A directory>
git pull repo-A-branch master
git remote rm repo-A-branch
```

## Cleaning up/splitting repo

THE SOLUTION WHAT WORKED:

Get BFG @ http://rtyley.github.io/bfg-repo-cleaner/

Many options, but I stripped by directory:

```bash
git clone --mirror ssh://triton:/data/git/all.git .
java -jar bfg.jar --delete-folders mods .
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

Comparing the results:

On each directory, generate a list of revs:
```bash
git rev-list --objects --all | awk '(NF > 1) { print $2 }' | sort -u >fileX
```

Then diff files.

## Repo size in KB

```bash
git count-objects -v | grep size-pack
```

## Links & Useful sites

* Git maintenance & data recovery:
  http://git-scm.com/book/en/Git-Internals-Maintenance-and-Data-Recovery
* Git for SVN users: http://git.or.cz/course/svn.html
* https://learngitbranching.js.org/
  * "the most visual and interactive way to learn Git on the web; you'll be
    challenged with exciting levels, given step-by-step demonstrations of
    powerful features, and maybe even have a bit of fun along the way."
* https://kbroman.org/github_tutorial/
  * "git/github guide a minimal tutorial"
* http://think-like-a-git.net/
  * "My goal with this site is to help you, Dear Reader, understand what those
    smug bastards [git knowers] are talking about."
    * Looks especially useful: http://think-like-a-git.net/halp.html, "If
      you've just lost some work in Git, and you're trying to recover your lost
      commits, this page is for you."
