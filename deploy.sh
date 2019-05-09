STATUS="$(git status)"

if [[ $STATUS == *"nothing to commit, working tree clean"* ]]
then
    hugo
    sed -i '/public' ./.gitignore
    git add .
    git commit -m "Edit .gitignore to publish"
    git push origin `git subtree split --prefix public master`:gh-pages --force
    git reset HEAD~
    git checkout .gitignore
else
    echo "Need clean working directory to publish"
fi