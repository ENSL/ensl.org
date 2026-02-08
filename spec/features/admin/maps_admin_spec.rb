require 'rails_helper'

# Admin Maps Management Feature Spec
# Tests map viewing, access control, and core admin functionality via the UI
RSpec.feature 'Admin manages maps', type: :feature, js: true do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before do
  end

  scenario 'regular user can view maps and their details with all fields' do
    sign_in_via_session(regular_user)

    map = create(:map, :full)

    visit '/maps'

    expect(page).to have_content(map.name)

    click_link map.name

    expect(page).to have_content(map.name)
    expect(page).to have_content(map.download)
    expect(page).to have_link(map.download)
  end

  scenario 'admin views all maps on index page' do
    sign_in_via_session(admin)

    map1 = create(:map, name: 'ns_eclipse')
    map2 = create(:map, name: 'ns_veil')
    map3 = create(:map, name: 'ns_summit')

    visit '/maps'

    expect(page).to have_content('ns_eclipse')
    expect(page).to have_content('ns_veil')
    expect(page).to have_content('ns_summit')
  end

  scenario 'admin can view individual map details' do
    sign_in_via_session(admin)
    map = create(:map, name: 'ns_caged', download: 'http://example.com/ns_caged.zip')

    visit "/maps/#{map.id}"

    expect(page).to have_content('ns_caged')
    expect(page).to have_content('http://example.com/ns_caged.zip')
  end

  scenario 'admin can access new map form from index' do
    sign_in_via_session(admin)

    visit '/maps'
    click_link 'New Map'

    expect(page).to have_current_path('/maps/new')
    expect(page).to have_field('map[name]')
    expect(page).to have_field('map[download]')
    expect(page).to have_button('Update Map')
  end

  scenario 'admin can access edit map form' do
    sign_in_via_session(admin)
    map = create(:map, name: 'ns_editable', download: 'http://example.com/test.zip')

    visit "/maps/#{map.id}"
    click_link 'Edit Map'

    expect(page).to have_current_path("/maps/#{map.id}/edit")
    expect(page).to have_field('map[name]', with: 'ns_editable')
    expect(page).to have_field('map[download]', with: 'http://example.com/test.zip')
  end

  scenario 'deleted maps do not appear in index listing' do
    sign_in_via_session(admin)

    active_map = create(:map, name: 'ns_active', deleted: false)
    deleted_map = create(:map, name: 'ns_deleted', deleted: true)

    visit '/maps'

    expect(page).to have_content('ns_active')
    expect(page).not_to have_content('ns_deleted')
  end

  scenario 'maps are sorted by name on index' do
    sign_in_via_session(admin)

    create(:map, name: 'ns_zulu')
    create(:map, name: 'ns_alpha')
    create(:map, name: 'ns_bravo')

    visit '/maps'

    # Get all text and find positions
    page_text = page.text
    alpha_pos = page_text.index('ns_alpha')
    bravo_pos = page_text.index('ns_bravo')
    zulu_pos = page_text.index('ns_zulu')

    expect(alpha_pos).to be < bravo_pos
    expect(bravo_pos).to be < zulu_pos
  end

  scenario 'admin has permission to create maps' do
    map = Map.new
    expect(map.can_create?(admin)).to be true
  end

  scenario 'admin has permission to edit maps' do
    map = create(:map, name: 'ns_test')
    expect(map.can_update?(admin)).to be true
  end

  scenario 'admin has permission to delete maps' do
    map = create(:map, name: 'ns_test')
    expect(map.can_destroy?(admin)).to be true
  end

  scenario 'non-admin user cannot access new map form' do
    sign_in_via_session(regular_user)

    visit '/maps/new'

    expect(page).to have_content('You are not allowed')
  end

  scenario 'non-admin user cannot access edit map form' do
    sign_in_via_session(regular_user)
    map = create(:map, name: 'ns_protected')

    visit "/maps/#{map.id}/edit"

    expect(page).to have_content('You are not allowed')
  end

  scenario 'regular user cannot create maps' do
    map = Map.new
    expect(map.can_create?(regular_user)).to be false
  end

  scenario 'regular user cannot edit maps' do
    map = create(:map, name: 'ns_test')
    expect(map.can_update?(regular_user)).to be false
  end

  scenario 'regular user cannot delete maps' do
    map = create(:map, name: 'ns_test')
    expect(map.can_destroy?(regular_user)).to be false
  end

  scenario 'classic maps scope filters maps starting with ns_' do
    classic1 = create(:map, name: 'ns_eclipse')
    classic2 = create(:map, name: 'ns_veil')
    custom = create(:map, name: 'co_custom')

    expect(Map.classic).to include(classic1)
    expect(Map.classic).to include(classic2)
    expect(Map.classic).not_to include(custom)
  end

  scenario 'with_name scope filters by exact name' do
    target_map = create(:map, name: 'ns_specific')
    other_map = create(:map, name: 'ns_other')

    result = Map.with_name('ns_specific')

    expect(result).to include(target_map)
    expect(result).not_to include(other_map)
  end

  scenario 'map to_s returns the map name' do
    map = create(:map, name: 'ns_toString')
    expect(map.to_s).to eq('ns_toString')
  end

  scenario 'soft delete sets deleted flag without removing record' do
    map = create(:map, name: 'ns_softdelete')
    original_id = map.id

    map.destroy

    reloaded = Map.find(original_id)
    expect(reloaded.deleted).to be true
    expect(Map.basic).not_to include(reloaded)
  end
end
