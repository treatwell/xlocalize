require 'spec_helper'
require 'fileutils'
require 'nokogiri'
require 'xlocalize/helper'

describe Xlocalize::Executor do
  describe 'when exporting' do

    it 'not contains excluded translations units in xliff' do
      xliff = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
        <file original="Target/en.lproj/only_exclude.strings" source-language="en" datatype="plaintext">
          <body>
            <trans-unit id="excl">
              <source>does not matter</source>
            </trans-unit>
          </body>
        </file>
        <file original="Target/en.lproj/should_exclude_some.strings" source-language="en" datatype="plaintext">
          <body>
            <trans-unit id="exclude_trans_unit">
              <source>does not matter as well</source>
            </trans-unit>
            <trans-unit id="should_keep">
              <source>should keep</source>
            </trans-unit>
          </body>
        </file>
      </xliff>
      eos
      export_file = StringIO.new

      allow(File).to receive(:exist?).and_return(false)
      allow(Xlocalize::Helper).to receive(:xcode_at_least?).with(9).and_return(true)
      allow(Xlocalize::Helper).to receive(:xcode_at_least?).with(9.3).and_return(true)
      allow(Xlocalize::Helper).to receive(:xcode_at_least?).with(10).and_return(false)
      allow(Kernel).to receive(:system).with('xcodebuild -exportLocalizations -localizationPath ./ -project Project.xcodeproj')
      allow(File).to receive(:open).with('en.xliff').and_return(xliff)
      allow(File).to receive(:open).with('en.xliff', 'w').and_yield(export_file)
      Xlocalize::Executor.new.export_master(nil, 'Project.xcodeproj', ['Target'], '##', 'en', ['exclude_trans_unit', 'excl'], false)
      
      files = Nokogiri::XML(export_file.string).xpath("//xmlns:file").map { |f| f['original'] }
      trans_units = Nokogiri::XML(export_file.string).xpath("//xmlns:trans-unit").map { |node| node['id'] }
      expect(files).to eq(['Target/en.lproj/should_exclude_some.strings'])
      expect(trans_units).to eq(['should_keep'])
    end

    describe 'with WTI setup' do
      class WebtranslateItMock
        attr_reader :push_xliff_file
        attr_reader :push_plurals_file
        def push_master(file, plurals_file)
          @push_xliff_file = file
          @push_plurals_file = plurals_file
        end
        def pull(locale)
          fname = Xlocalize::Helper.xcode_at_least?(10) ? "#{locale}.xcloc/Localized Contents/#{locale}.xliff" : "#{locale}.xliff"
          { 'xliff' => Nokogiri::XML(File.open(fname)).to_xml }
        end
      end

      xliff_name = Xlocalize::Helper.xcode_at_least?(10) ? "en.xcloc/Localized Contents/en.xliff" : "en.xliff"
      plurals_name = "#{xliff_name}_plurals.yml"

      wti = WebtranslateItMock.new
      fixture_path = 'spec/fixtures/ImportExportExample/'
      Xlocalize::Executor.new.export_master(wti, fixture_path << '/ImportExportExample.xcodeproj', ['ImportExportExample'], '##', 'en', false)

      it 'should create a YAML file for plurals in project' do
        plurals_yml = YAML.load_file(plurals_name)
        expected_yml = {
          'en' => {
            'ImportExportExample/en.lproj/and_plurals.stringsdict' => {
              'users_count' => {
                'one' => '%d user',
                'other' => '%d users'
              }
            }
          }
        }
        expect(plurals_yml.to_a).to eq(expected_yml.to_a)
      end

      it 'should pass correct xliff file for upload' do
        expect(wti.push_xliff_file.path).to eq(File.open(xliff_name, 'r') { |f| f.path })
      end

      it 'should pass correct plurals file for upload' do
        expect(wti.push_plurals_file.path).to eq(File.open(plurals_name, 'r') { |f| f.path })
      end

      it 'should have plurals filtered from xliff file' do
        doc = Nokogiri::XML(File.open(xliff_name))
        trans_units = doc.xpath("//xmlns:trans-unit").map { |node| node['id'] }
        expect(trans_units.include? 'users_count').to eq(false)
      end
    end
  end
end
