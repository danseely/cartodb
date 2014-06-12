# coding: UTF-8

require_relative '../spec_helper'

include CartoDB

describe CartoDB::Permission do

  before(:all) do
    CartoDB::Varnish.any_instance.stubs(:send_command).returns(true)
    @user = create_user(:quota_in_bytes => 524288000, :table_quota => 500)
  end

  describe '#create' do
    it 'tests basic creation' do
      acl_initial = []
      acl_with_data = [
        {
          user: {
            id: UUIDTools::UUID.timestamp_create.to_s,
            username: 'another_username'
          },
          type: Permission::TYPE_READONLY
        }
      ]

      permission = Permission.new(
          owner_id:       @user.id,
          owner_username: @user.username
          #check default acl is correct
      )
      permission.save

      permission.id.should_not eq nil
      permission.owner_id.should eq @user.id
      permission.owner_username.should eq @user.username
      permission.acl.should eq acl_initial

      permission.acl = acl_with_data
      permission.save

      permission.acl.should eq acl_with_data

      # Nil should reset to default value
      permission.acl = nil
      permission.acl.should eq acl_initial

      # Missing owner
      permission2 = Permission.new
      expect {
        permission2.save
      }.to raise_exception

      # Owner helper methods
      permission2.owner = @user
      permission2.save
      permission2.owner.should eq @user
      permission2.owner_id.should eq @user.id
      permission2.owner_username.should eq @user.username

      # invalid ACL formats
      expect {
        permission2.acl = 'not an array!'
      }.to raise_exception CartoDB::PermissionError

      expect {
        permission2.acl = [
            'aaa'
        ]
      }.to raise_exception CartoDB::PermissionError

      expect {
        permission2.acl = [
          {}
        ]
      }.to raise_exception CartoDB::PermissionError

      expect {
        permission2.acl = [
          {
            # missing fields
            wadus: 'aaa'
          }
        ]
      }.to raise_exception CartoDB::PermissionError

      user2 = create_user(:quota_in_bytes => 524288000, :table_quota => 500)
      expect {
        permission2.acl = [
          {
            user: {
              id: user2.id,
              username: user2.username
            },
            type: Permission::TYPE_READONLY,
            # Extra undesired field
            wadus: 'aaa'
          }
        ]
      }.to raise_exception CartoDB::PermissionError

      # Wrong permission type
      expect {
        permission2.acl = [
          {
            user: {
              id: user2.id,
              username: user2.username
            },
            type: '123'
          }
        ]
      }.to raise_exception CartoDB::PermissionError

    end
  end

  describe '#permissions_methods' do
    it 'checks permission_for_user and is_owner methods' do
      user2 = create_user(:quota_in_bytes => 524288000, :table_quota => 500)
      user3 = create_user(:quota_in_bytes => 524288000, :table_quota => 500)

      permission = Permission.new(
        owner_id:       @user.id,
        owner_username: @user.username
      )
      permission.acl = [
        {
          user: {
            id: user2.id,
            username: user2.username
          },
          type: Permission::TYPE_READONLY
        }
      ]

      permission.save
      # Here try full reload of model
      permission = Permission.where(id:permission.id).first

      permission.should_not eq nil

      permission.is_owner(@user).should eq true
      permission.is_owner(user2).should eq false
      permission.is_owner(user3).should eq false

      permission.permission_for_user(@user).should eq Permission::TYPE_READWRITE
      permission.permission_for_user(user2).should eq Permission::TYPE_READONLY
      permission.permission_for_user(user3).should eq nil
    end
  end

end