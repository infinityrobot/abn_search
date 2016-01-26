require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))

describe ABNSearch::Entity do
  describe "valid? class method" do
    it "should identify a valid ABN" do
      good_abns.each do |abn|
        expect(abn.valid?).to be true
      end
    end

    it "should identify an invalid ABN" do
      bad_abns.each do |abn|
        expect(abn.valid?).to be false
      end
    end
  end

  describe "valid_acn? class method" do
    it "should identify a valid ACN" do
      good_acns.each do |acn|
        expect(acn.valid_acn?).to be true
      end
    end

    it "should identify an invalid ACN" do
      bad_acns.each do |acn|
        expect(acn.valid_acn?).to be false
      end
    end
  end

  describe ABNSearch::Client do
    describe "sanity check" do
      it "should not attempt to query ABR without a GUID" do
        e = ArgumentError
        expect { good_abns.first.update_from_abr! }.to raise_error(e)
        expect { good_acns.first.update_from_abr_using_acn! }.to raise_error(e)
      end

      it "should fail if you use a fake GUID" do
        ABNSearch::Client.new("fake-guid")
        e = RuntimeError
        expect { good_abns.first.update_from_abr! }.to raise_error(e)
        expect { good_acns.first.update_from_abr_using_acn! }.to raise_error(e)
      end

      it "should work if you use a real GUID and a real ABN" do
        ABNSearch::Client.new(ENV["ABN_LOOKUP_GUID"])
        primary_name = good_abns.first.update_from_abr!.primary_name
        expect(primary_name).to be_a String
        expect(primary_name.length).to be > 0
      end

      it "should work if you use a real GUID and a real ACN" do
        ABNSearch::Client.new(ENV["ABN_LOOKUP_GUID"])
        primary_name = good_acns.first.update_from_abr_using_acn!.primary_name
        expect(primary_name).to be_a String
        expect(primary_name.length).to be > 0
      end

      it "should not return a TypeError if you get only one result" do
        ABNSearch::Client.new(ENV["ABN_LOOKUP_GUID"])
        expect do
          ABNSearch::Client.search_by_name("asdf :asdfasdfasdfadsf")
        end.not_to raise_error
      end
    end
  end

  def good_abns
    [
      ABNSearch::Entity.new(abn: 99_124_391_073),
      ABNSearch::Entity.new(abn: "99124391073"),
      ABNSearch::Entity.new(abn: "99 12 439 10 73 "),
      ABNSearch::Entity.new(abn: "46 110 483 513")
    ]
  end

  def bad_abns
    [
      ABNSearch::Entity.new(abn: 99_124_391_07),
      ABNSearch::Entity.new(abn: 99_124_391_071_1),
      ABNSearch::Entity.new(abn: "abn"),
      ABNSearch::Entity.new(abn: "99124391072")
    ]
  end

  def good_acns
    [
      ABNSearch::Entity.new(acn: 124_391_073),
      ABNSearch::Entity.new(acn: "124391073"),
      ABNSearch::Entity.new(acn: " 12 439 10 73 "),
      ABNSearch::Entity.new(acn: "110 483 513")
    ]
  end

  def bad_acns
    [
      ABNSearch::Entity.new(acn: 124_391_07),
      ABNSearch::Entity.new(acn: 124_391_071_1),
      ABNSearch::Entity.new(acn: "acn"),
      ABNSearch::Entity.new(acn: "124391072")
    ]
  end
end
