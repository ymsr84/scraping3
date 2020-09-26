require_relative 'lib/yankee'

path = 'src/thermaltake/1.html'
# url = 'https://www.thermaltakeusa.com/products/chassis.html?product_list_limit=30&p=1'
url = 'https://jp.thermaltake.com/products/chassis.html?product_list_limit=30&p=1'

Yankee.thermaltake(path,url)
