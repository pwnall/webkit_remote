require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe WebkitRemote::Client::RemoteObjectGroup do
  before :each do
    @client = WebkitRemote.local port: 9669
    @client.navigate_to fixture_url(:runtime)

    @object1 = @client.remote_eval '({})', group: 'g1'
    @object2 = @client.remote_eval '({})', group: 'g1'
    @object3 = @client.remote_eval '({})', group: 'g2'
    @group1 = @client.object_group 'g1'
    @group2 = @client.object_group 'g2'
  end
  after :each do
    @object1.release
    @object2.release
    @object3.release
    @client.close
  end

  describe 'include?' do
    it 'is true for objects in the group' do
      @group1.include?(@object1).must_equal true
      @group1.include?(@object2).must_equal true
      @group2.include?(@object3).must_equal true
    end
    it 'is false for objects in different groups' do
      @group2.include?(@object2).must_equal false
      @group1.include?(@object3).must_equal false
      @group2.include?(@object1).must_equal false
    end
  end

  describe 'after an object release' do
    before :each do
      @object1.release
    end

    it 'does not include the released object' do
      @group1.include?(@object1).must_equal false
    end
    it 'includes unreleased objects' do
      @group1.include?(@object2).must_equal true
    end
    it 'does not release the whole group' do
      @group1.released?.must_equal false
    end

    describe 'after releasing the only other object in the group' do
      before :each do
        @object2.release
      end

      it 'released the whole group' do
        @group1.released?.must_equal true
      end
      it 'removes the group from the client' do
        @client.object_group('g1').must_equal nil
      end
    end
  end

  describe '#release_all' do
    before :each do
      @group1.release_all
    end

    it 'releases all the objects in the group' do
      @object1.released?.must_equal true
      @object2.released?.must_equal true
    end
    it 'does not release objects in other groups' do
      @object3.released?.must_equal false
    end
    it 'releases the group and removes the group from the client' do
      @group1.released?.must_equal true
      @client.object_group('g1').must_equal nil
    end
  end
end
