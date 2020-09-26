require 'net/http'
require 'nokogiri'
require 'fileutils'
require 'json'

module Yankee
  class Index
    @records = []

    # 引数のpathにHTMLファイルが無い,又はDownload後指定時間経過していたら引数のURLからDownloadする
    def self.file_exist(path,url)
      # pathにファイルが存在しない場合urlから取得した内容で書き込み
      write_file(path, read_website(url)) if !(File.exist?(path))
      # pathにあるファイルの作成時刻が現在時刻の7日以前の場合urlから取得した内容で書き込み
      write_file(path, read_website(url)) if 86400 < (Time.now - File::Stat.new(path).mtime)
      # 現在時刻はTime.now pathの最終更新日時 File::Stat.new(path).mtime 差 "#{Time.now - File::Stat.new(path).mtime}秒"
    end

    # 引数のURLからHTMLファイルを取得
    def self.read_website(url)
      sleep 1
      Net::HTTP.get(URI(url))
    end

    # 引数のpathのファイルを開く
    def self.read_file(path)
      File.read(path)
    end

    # 引数のファイル名と内容で保存
    def self.write_file(path, text)
      File.open(path, 'w') { |file| file.write(text) }
    end

    # 引数のpathからnokogiriのパーサーを通してインスタンス生成
    def self.nokogiri(path)
      Nokogiri::HTML.parse(read_file(path), nil, 'utf-8')
    end
    # 引数のURIからnokogiriのパーサーを通してインスタンス生成
    def self.nokogiri_from_uri(uri)
      Nokogiri::HTML.parse(read_website(uri), nil, 'utf-8')
    end

    # 全ての製品一覧ページをダウンロードする
    def self.get_local_html(path,url)
      # nokogiri展開
      doc = nokogiri(path)
      # プロダクトの合計数の記載XPathは:doc.xpath('//span[@class = "toolbar-number"]')[2].text
      # 2ページ以降から,プロダクトの合計数/ページあたりの表示数である30の商を切り上げした数(全ページ数)まで,繰り返し
      # jp.thermaltake.comの場合 インデックス番号[0]
      # p doc.xpath('//span[@class = "toolbar-number"]')[0].text
      # hermaltakeusaの場合　インデックス番号[2]
      # p doc.xpath('//span[@class = "toolbar-number"]')[2].text
      (2..((doc.xpath('//span[@class = "toolbar-number"]')[0].text.to_f / 30).ceil)).each { |i|
        # pathの末尾の数字[0-9]+をページ数[i]に置き換えてfile_exist実行
        file_exist(path.sub(/[0-9]+/, i.to_s),url.chop<<i.to_s)
      }
    end

    # 条件[*.html]でpathを検索し昇順に製品ページのURLをスクレイピングし2次元配列で返す
    def self.product_url_scraping
      Dir.glob('src/thermaltake/*.html').sort.each { |html_file_path|
      deconstruct(html_file_path)
    }
    end

    # '//a[@class = "product-item-link"]'の子要素(各製品)を列挙し処理を実行
    def self.deconstruct(html_file_path)
      nokogiri(html_file_path).xpath('//a[@class = "product-item-link"]').each { |element|
        # p "#{count += 1}:#{text_and_href(element)}"
        @records.push({
          #エスケープ文字の除去,スペースをアンダーバーに置換後,キー:nameに代入
          name: element.text.gsub("\t", "").gsub("\n", "").gsub(" ","_").gsub("\"","inch").gsub("/","?"),
          url: element.attributes['href'].value,
          })
      }
    end

    # 引数の内容でjson形式で保存
    def self.write_json()
      write_file("src/thermaltake/name_and_url.json", {records: @records}.to_json)
    end

    # 引数の内容でjson形式で保存
    def self.write_json2()
      write_file("src/thermaltake/specs.json", {records: @records}.to_json)
    end

    # 引数のファイル名と内容で保存
    def self.write_file(path, text)
      File.open(path, 'w') { |file| file.write(text) }
    end

    #メインメソッド
    def self.thermaltake(path,url)
      p "****************************************************************"
      file_exist(path,url)
      # 全ての製品一覧ページをダウンロードする
      get_local_html(path,url)
      product_url_scraping
      write_json
      # p @records.size
      # 各製品ページへのアクセス
      @records.each_with_index{ |record,i|
        # p "----------------------------"
        # puts "#{i}:#{record[:name]}"
        # 製品ページのHTMLファイルの存在確認
        file_exist("src/thermaltake/#{record[:name]}.html",record[:url])
        p "#{record[:name]} file exist"
        # docに製品ページをnokogiriパーサーに通して代入
        doc = nokogiri("src/thermaltake/#{record[:name]}.html")
        # p @records[i][:model] = doc.xpath('//td[@data-th = "モデル"]').text
        @records[i][:モデル] = doc.xpath('//table[@class = "data table additional-attributes"]/tbody/tr/td[@data-th = "モデル"]').text
        @records[i][:重量] = doc.xpath('//table[@class = "data table additional-attributes"]/tbody/tr/td[@data-th = "重量(ケース)"]').text.scan(/\d+(?:\.\d+)?/)
        @records[i][:寸法] = doc.xpath('//table[@class = "data table additional-attributes"]/tbody/tr/td[contains(@data-th,"外形寸法")]').text
        dimension = @records[i][:寸法].scan(/\d+(?:\.\d+)?/)
        @records[i][:高さ] = dimension[0]
        @records[i][:幅] = dimension[1]
        @records[i][:奥行き] = dimension[2]
        # doc.xpath('//table[@class = "data table additional-attributes"]/tbody/tr').each { |node|
        #     # @records[i]["シリーズ"] = node.xpath('./td').text if node.xpath('./th').text == "シリーズ"
        #   # @records[i][node.xpath('./th').text.gsub("\t", "").gsub("\n", "").gsub(" ","_")] = node.xpath('./td').text.gsub("\t", "").gsub("\n", "").gsub(" ","_")
        # }
        # break
        # break if i == 3
      }
      @records.each_with_index{ |record,i|
        p "#{record[:モデル]},#{record[:重量]},#{record[:高さ]},#{record[:幅]},#{record[:奥行き]}"
        # #{record[:寸法]}
        # break
        # break if  i == 3
      }
      write_json2
      p "****************************************************************"
    end
=begin
=end
  end
end
