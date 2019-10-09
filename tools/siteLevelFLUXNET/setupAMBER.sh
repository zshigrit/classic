# First, we get a map of the repository by establishing where this script is located, then
# deducing where the root of the repository is.
script_location="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
rootdir=${script_location%%/tools*}

#singularity exec $container yes | R --vanilla << EOF
mkdir -p ~/R/x86_64-pc-linux-gnu-library/3.6
yes | R --vanilla << EOF
setwd("$rootdir/../AMBER/rpackage")
install.packages("amber", repos=NULL, lib="~/R/x86_64-pc-linux-gnu-library/3.6")
EOF

# Mess with the configuration.R file here, then run it
sed -i "/modelOutputType <-/s|\".*\"|\"siteLevel\"| ; /amber.gitrepo.path <-/s|\".*\"|\"$rootdir/../AMBER\"| ; /mod.csv.path <-/s|#mod.csv.path <- \".*\"|mod.csv.path <- \"$rootdir/outputFiles/FLUXNETsites\"| ; /ref.csv.path <-/s|\".*\"|\"$rootdir/inputFiles/observationalDataFLUXNET\"| ; /outputDir <-/s|\".*\"|\"$rootdir/outputFiles/AMBER\"| ; /mod.id <-/s|\".*\"|\"FLUXNET\"| ; /mod.path <-/s|\".*\"|\"nopath\"| ; /ref.path <-/s|\".*\"|\"norefpath\"|" $rootdir/../AMBER/scripts/configure.R

sed -i "/pdflatex/s|system|#system|" $rootdir/../AMBER/scripts/runSiteLevel.R

Rscript $rootdir/../AMBER/scripts/configure.R 2>/dev/null

sed -i "/pdflatex/s|#system|system|" $rootdir/../AMBER/scripts/runSiteLevel.R

for file in outputFiles/AMBER/*.tex; do
  pandoc -s $file -o ${file%.tex}.html
done