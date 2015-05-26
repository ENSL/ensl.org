module Features
  module ServerHelpers
    def test_server_creation_and_editing
      dns = 'ServerDns.com'
      ip = '192.168.1.1'
      port = '8000'
      password = 'secret'
      name = 'MyNsServer'
      description = 'My NS Server'
      irc = '#some_channel'

      visit new_server_path
      fill_in 'Dns', with: dns
      fill_in 'server_ip', with: ip
      fill_in 'server_port', with: port
      fill_in 'Password', with: password
      fill_in 'Name', with: name
      fill_in 'Description', with: description
      fill_in 'Irc', with: irc
      check 'Available for officials?'
      click_button 'Save'

      expect(page).to have_content(dns)
      expect(page).to have_content("#{ip}:#{port}")
      expect(page).to have_content(password)
      expect(page).to have_content(irc)
      expect(page).to have_content(description)

      click_link 'Edit Server'

      fill_in 'Dns', with: "#{dns}2"
      fill_in 'server_ip', with: "192.168.1.2"
      fill_in 'server_port', with: "8001"
      fill_in 'Password', with: "#{password}2"
      fill_in 'Name', with: "#{name}2"
      fill_in 'Description', with: "#{description}2"
      fill_in 'Irc', with: "#{irc}2"
      check 'Available for officials?'
      click_button 'Save'

      expect(page).to have_content("192.168.1.2:8001")
      expect(page).to have_content("#{dns}2")
      expect(page).to have_content("#{password}2")
      expect(page).to have_content("#{irc}2")
      expect(page).to have_content("#{description}2")
    end
  end
end