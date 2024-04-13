require 'spec_helper'

describe SitemapEntry do
    subject { FactoryGirl.create(:sitemap_entry) }

    expect_it { to belong_to(:site).optional }
    expect_it { to belong_to(:revision).optional }
    expect_it { to have_many :issues }

    describe 'scope' do
        describe 'coverage' do
            before do
                FactoryGirl.create(
                    :sitemap_entry,
                    url: '1',
                    code: 200
                )
                FactoryGirl.create(
                    :sitemap_entry,
                    url: '2',
                    code: 404
                )
                FactoryGirl.create(
                    :sitemap_entry,
                    url: '3',
                    code: 301,
                    coverage: true
                )

                @coverage = []
                @coverage << FactoryGirl.create(
                    :sitemap_entry,
                    url: '4',
                    code: 200,
                    coverage: true
                )
                @coverage << FactoryGirl.create(
                    :sitemap_entry,
                    url: '5 ',
                    code: 200,
                    coverage: true
                )
            end

            it 'returns entries with marked as coverage and code 200' do
                expect(described_class.coverage.map(&:url).sort).to eq @coverage.map(&:url).sort
            end
        end

        describe ':with_issues' do
            it 'returns entries with entries'
        end

        describe ':without_issues' do
            it 'returns entries without entries'
        end

        describe ':default' do
            it 'sorts entries by URL'
        end
    end

    it 'sets #digest' do
        subject.url = 'test'
        subject.save

        expect(subject.digest).to eq 'test'.persistent_hash
    end
end
