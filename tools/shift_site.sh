
# Usage - sh tools/shift_site.sh $site_abbr

abbr=$1

mv data/sites/$1.yml data/transition-sites/
rm data/mappings/$1.csv
for domain in $(grep -o '[^ ]*uk' data/transition-sites/$1.yml | grep -v 'www.gov.uk' | grep -v 'blog.gov.uk' | sed 's/http[s?]:\/\///g' | sort | uniq )
do
	rm data/tests/$domain.csv
done
