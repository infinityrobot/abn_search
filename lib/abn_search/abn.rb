#
# ABN Object
#
module ABNSearch
  class Entity
    attr_accessor :acn, :abn, :abn_current, :entity_type, :status, :main_name,
                  :trading_name, :business_name, :legal_name, :legal_name2,
                  :other_trading_name, :active_from_date, :address_state_code,
                  :address_post_code, :address_from_date, :last_updated,
                  :gst_from_date, :primary_name, :secondary_name

    # Initialize an ABN object
    #
    # @param options [Hash] hash of options
    # @option options [String] :abn an Australian Business Number
    # @option options [String] :acn an Australian Company Number
    # @option options [Hash] :abr_detail raw output from the ABR
    # @return [ABNSearch::Entity] an instance of ABNSearch::Entity is returned
    def initialize(options = {})
      # try to mash the input into something usable
      @abn = strip_rjust(options[:abn], 11) unless options[:abn].nil?
      @acn = strip_rjust(options[:acn], 9) unless options[:acn].nil?

      unless options[:abr_detail].nil?
        process_raw_abr_detail(result: :success, payload: options[:abr_detail])
      end
      self
    end

    # Update the ABN object with information from the ABR via ABN search
    #
    # @return [self]
    def update_from_abr!
      abr_detail = ABNSearch::Client.search(@abn)
      process_raw_abr_detail(abr_detail)
      self
    end

    # Update the ABN object with information from the ABR via ASIC search
    #
    # @return [self]
    def update_from_abr_using_acn!
      abr_detail = ABNSearch::Client.search_by_acn(@acn)
      process_raw_abr_detail(abr_detail)
      self
    end

    # Return array of business names
    #
    # @return [array] business names
    def names
      [@main_name, @business_name, @trading_name, @other_trading_name,
       @legal_name, @legal_name2].delete_if(&:nil?)
    end

    # Select a primary business name
    #
    # @return [String] business name
    def primary_name
      names.first
    end

    # Select a relevant secondary business name
    #
    # @return [String] business name
    def secondary_name
      names.find { |n| !/#{primary_name}/i.match(n) }
    end

    # Test to see if an ABN is valid
    #
    # @return [Boolean] true or false
    def valid?
      return false unless @abn.is_a?(String)
      return false if (@abn =~ /^[0-9]{11}$/).nil?
      weighting = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
      chksum = 0
      (0..10).each do |d|
        chksum += (@abn[d].to_i - (d.zero? ? 1 : 0)) * weighting[d]
      end
      return (chksum % 89) == 0
    rescue => e
      puts "Error: #{e.class}\n#{e.backtrace.join("\n")}"
      return false
    end

    # Just check if an ABN is valid
    # @param abn [String or Integer] the Australian Business Number
    # @return [Boolean]
    def self.valid?(abn)
      new(abn: abn).valid?
    rescue => e
      puts "Error: #{e.class}\n#{e.backtrace.join("\n")}"
      return false
    end

    # Test to see if the ABN has a valid ACN
    #
    # return [Boolean]
    def valid_acn?
      return false unless @acn.is_a?(String)
      return false if (@acn =~ /^[0-9]{9}$/).nil?
      weighting = [8, 7, 6, 5, 4, 3, 2, 1]
      chksum = 0
      (0..7).each do |d|
        chksum += @acn[d].to_i * weighting[d]
      end
      return (10 - chksum % 10) % 10 == @acn[8].to_i
    rescue => e
      puts "Error: #{e.class}\n#{e.backtrace.join("\n")}"
      return false
    end

    # Just check if an ACN is valid
    # @param acn [String or Integer] the Australian Company Number
    # @return [Boolean]
    def self.valid_acn?(acn)
      new(acn: acn).valid_acn?
    rescue => e
      puts "Error: #{e.class}\n#{e.backtrace.join("\n")}"
      return false
    end

    # Return a nicely formatted string for valid abns, or
    # an empty string for invalid abns
    #
    # @return [String]
    def to_s
      valid? ? format("%s%s %s%s%s %s%s%s %s%s%s", @abn.split("")) : ""
    end

    # Return a nicely formatted string for valid acns, or
    # an empty string for invalid acns
    #
    # @return [String]
    def acn_to_s
      valid_acn? ? format("%s%s%s %s%s%s %s%s%s", @acn.split("")) : ""
    end

    private

    # Parse the ABR detail
    #
    # @return [self]
    def process_raw_abr_detail(abr_detail)
      if abr_detail[:result] == :success
        body = abr_detail[:payload]
      else
        fail "Exception: #{abr_detail[:payload][:exception_description]}"
      end

      @acn                = body[:asic_number] rescue nil
      @abn                = body[:abn][:identifier_value] rescue nil
      @abn_current        = body[:abn][:is_current_indicator] rescue nil
      @entity_type        = body[:entity_type][:entity_description] rescue nil
      @status             = body[:entity_status][:entity_status_code] rescue nil
      @main_name          = body[:main_name][:organisation_name] rescue nil
      @trading_name       = body[:main_trading_name][:organisation_name] rescue nil
      @business_name      = body[:business_name][:organisation_name] rescue nil
      @legal_name         = "#{body[:legal_name][:given_name]} #{body[:legal_name][:family_name]}" rescue nil
      @legal_name2        = body[:full_name] rescue nil
      @other_trading_name = body[:other_trading_name][:organisation_name] rescue nil
      @active_from_date   = body[:entity_status][:effective_from] rescue nil
      @address_state_code = body[:main_business_physical_address][:state_code] rescue nil
      @address_post_code  = body[:main_business_physical_address][:postcode] rescue nil
      @address_from_date  = body[:main_business_physical_address][:effective_from] rescue nil
      @last_updated       = body[:record_last_updated_date] rescue nil
      @gst_from_date      = body[:goods_and_services_tax][:effective_from] rescue nil
      @primary_name       = primary_name
      @secondary_name     = secondary_name
      0
    end

    def strip_rjust(string, number)
      string.to_s.gsub(/\s+/, "").rjust(number, "0")
    end
  end
end
