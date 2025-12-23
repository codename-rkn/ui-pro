include Warden::Test::Helpers
Warden.test_mode!

feature 'Edit global settings' do
    subject { Settings }
    let(:site) { FactoryGirl.create :site }
    let(:user) { FactoryGirl.create :user }

    after(:each) do
        Warden.test_reset!
    end

    def submit
        find( :xpath, "//input[@type='submit']" ).click
    end

    def sidebar_submit
        find('#sidebar button').click
        sleep 1
    end

    feature 'authenticated user' do
        before do
            user.sites << site

            login_as( user, scope: :user )
            visit settings_path
        end

        scenario 'it updates the global options' do
            expect(SCNR::Engine::Options).to receive(:update).with(subject.to_scanner_options)
            expect(SCNR::Engine::HTTP::Client).to receive(:reset)

            submit
        end

        scenario 'has title' do
            expect(page).to have_title 'Settings'
        end

        scenario 'sees profile form' do
            expect(find('.profile-form')).to be_truthy
        end

        scenario 'can submit form using sidebar button', js: true do
            fill_in 'Proxy host', with: 'stuff.com'

            sidebar_submit

            expect(subject.http_proxy_host).to eq 'stuff.com'
        end

        feature 'option' do
            feature 'Scans' do
                feature 'Maximum parallel scans' do
                    feature 'when set manually', js: true do
                        before do
                            fill_in 'Maximum parallel scans', with: 10
                            sidebar_submit
                        end

                        scenario 'can be set to a number' do
                            expect(subject.max_parallel_scans).to eq 10
                        end

                        scenario 'shows manual setting alert' do
                            expect(page).to have_css '#max_parallel_scans-help-block'
                        end

                        scenario 'does not show auto alert' do
                            expect(page).to_not have_css '#max_parallel_scans_auto-help-block'
                        end
                    end

                    feature 'when Auto is checked', js: true do
                        before do
                            check 'Auto'
                        end

                        scenario 'can be set to auto' do
                            sidebar_submit

                            expect(subject).to be_max_parallel_scans_auto
                        end

                        scenario 'disables input' do
                            expect(page).to have_field 'Maximum parallel scans', disabled: true
                        end

                        scenario 'shows auto alert' do
                            expect(page).to have_css '#max_parallel_scans_auto-help-block'
                        end

                        scenario 'does not show manual setting alert' do
                            expect(page).to_not have_css '#max_parallel_scans-help-block'
                        end

                        feature 'and unchecked' do
                            before do
                                uncheck 'Auto'
                            end

                            scenario 'enables input' do
                                expect(page).to have_field 'Maximum parallel scans', disabled: false
                            end

                            scenario 'does not show auto alert' do
                                expect(page).to_not have_css '#max_parallel_scans_auto-help-block'
                            end

                            scenario 'shows manual setting alert' do
                                expect(page).to have_css '#max_parallel_scans-help-block'
                            end
                        end
                    end

                    feature 'when the value is less than an equivalent site setting' do
                        before do
                            site.profile.max_parallel_scans = 2
                            site.save
                        end

                        scenario 'shows error' do
                            fill_in 'Maximum parallel scans', with: 1
                            submit

                            expect(find('div.setting_max_parallel_scans.has-error')).to have_content "#{site.url} has a limit of #{site.profile.max_parallel_scans}"
                        end
                    end

                    feature 'when the value is 0' do
                        scenario 'shows error' do
                            fill_in 'Maximum parallel scans', with: 0
                            submit

                            expect(find('div.setting_max_parallel_scans.has-error')).to have_content 'must be greater than 0'
                        end
                    end

                    feature 'when its value is less than 0' do
                        scenario 'shows error' do
                            fill_in 'Maximum parallel scans', with: -1
                            submit

                            expect(find('div.setting_max_parallel_scans.has-error')).to have_content 'must be greater than 0'
                        end
                    end

                end
            end

            feature 'HTTP' do
                scenario 'can set Proxy host' do
                    fill_in 'Proxy host', with: 'stuff.com'
                    submit

                    expect(subject.http_proxy_host).to eq 'stuff.com'
                end

                scenario 'can set Proxy port' do
                    fill_in 'Proxy port', with: '8080'
                    submit

                    expect(subject.http_proxy_port).to eq 8080
                end

                scenario 'can set Proxy username' do
                    fill_in 'Proxy username', with: 'blah'
                    submit

                    expect(subject.http_proxy_username).to eq 'blah'
                end

                scenario 'can set Proxy password' do
                    fill_in 'Proxy password', with: 'blah'
                    submit

                    expect(subject.http_proxy_password).to eq 'blah'
                end

                scenario 'can set Request queue size' do
                    fill_in 'Request queue size', with: 20
                    submit

                    expect(subject.http_request_queue_size).to eq 20
                end

                scenario 'can set Request timeout' do
                    fill_in 'Request timeout', with: 2000
                    submit

                    expect(subject.http_request_timeout).to eq 2000
                end

                scenario 'can set Redirect limit' do
                    fill_in 'Redirect limit', with: 10
                    submit

                    expect(subject.http_request_redirect_limit).to eq 10
                end

                scenario 'can set Maximum response size' do
                    fill_in 'Maximum response size', with: 1000
                    submit

                    expect(subject.http_response_max_size).to eq 1000
                end
            end

            feature 'Browser' do
                scenario 'can set Processes' do
                    fill_in 'Processes', with: 10
                    submit

                    expect(subject.dom_pool_size).to eq 10
                end

                scenario 'can set Time to live' do
                    fill_in 'Time to live', with: 10
                    submit

                    expect(subject.dom_worker_time_to_live).to eq 10
                end

                scenario 'can set Timeout' do
                    fill_in 'Timeout', with: 10
                    submit

                    expect(subject.dom_job_timeout).to eq 10
                end
            end
        end
    end

    feature 'non authenticated user' do
        before do
            user
            visit settings_path
        end

        scenario 'gets redirected to the login page' do
            expect(current_url).to eq new_user_session_url
        end
    end
end
