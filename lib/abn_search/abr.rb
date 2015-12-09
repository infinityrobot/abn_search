#
# ABR Search
#
# Request examples;
#
# Search by ABN
# > a = ABNSearch::Client.new("your-guid")
# > result = a.search("56206894472")
#
# Search by name and return an array of results
# > a = ABNSearch::Client.new("your-guid")
# > result = a.search_by_name("Sony", states: ["NSW", "VIC"])
# > another_result = a.search_by_name("Sony", postcode: 2040)
#

require "savon"

module ABNSearch
  class Client
    ENDPOINT = "http://www.abn.business.gov.au/abrxmlsearch/ABRXMLSearch.asmx?WSDL"

    @@errors          = []
    @@guid            = ENV["ABN_LOOKUP_GUID"] || nil
    @@proxy           = nil
    @@client_options  = {}

    attr_accessor :errors, :guid, :proxy, :client_options

    # Setup a new instance of the ABN search class.
    #
    # @param [String] guid - the ABR GUID for Web Services access
    # @param [Hash] options - options detailed below
    # @option options [String] :proxy Proxy URL string if required
    # @return [ABNSearch]
    #
    def initialize(guid = ENV["ABN_LOOKUP_GUID"], options = {})
      @@guid = guid
      @@proxy = options[:proxy] || nil
      @@client_options = { wsdl: ENDPOINT }
      @@client_options.merge!(proxy: @@proxy) unless @@proxy.nil?
      self
    end

    # Performs an ABR search by ASIC
    #
    # @param [String] acn - the acn you wish to search for
    # @return [Hash] a hash containing :result & :payload
    def self.search_by_acn(acn)
      invalid_error = "ACN #{acn} is invalid"
      fail ArgumentError, invalid_error unless ABNSearch::Entity.valid_acn?(acn)
      check_guid

      client = Savon.client(@@client_options)
      response = client.call(:search_by_asi_cv201408,
                             message: { authenticationGuid: @@guid,
                                        searchString: acn.delete(" "),
                                        includeHistoricalDetails: "N"
                                      })

      validate_response(response, :search_by_asi_cv201408_response)
    end

    # Performs an ABR search by ABN
    #
    # @param [String] abn - the abn you wish to search for
    # @return [Hash] a hash containing :result & :payload
    def self.search(abn)
      invalid_error = "ACN #{abn} is invalid"
      fail ArgumentError, invalid_error unless ABNSearch::Entity.valid?(abn)
      check_guid

      client = Savon.client(@@client_options)
      response = client.call(:search_by_ab_nv201408,
                             message: { authenticationGuid: @@guid,
                                        searchString: abn.gsub(/\s+/, ""),
                                        includeHistoricalDetails: "N"
                                      })
      validate_response(response, :search_by_ab_nv201408_response)
    end

    # Performs an ABR search by name
    #
    # @param [String] name - the search term
    # @param [Hash] options hash - :states, :postcode
    # @option options [Array] :states - a list of states you which to include
    # @option options [String] :postcode - a postcode to filter the search by
    # @param [String] postcode - the postcode you wish to filter by
    # TODO: clean up this method
    def self.search_by_name(name, options = {})
      fail ArgumentError, "No search string provided" unless name.is_a?(String)
      check_guid

      options[:states] ||= %w(NSW QLD VIC SA WA TAS ACT NT)
      client = Savon.client(@@client_options)
      request = {
        externalNameSearch: {
          authenticationGuid: @@guid,
          name: name,
          filters: {
            nameType: {
              tradingName: options[:trading_name] || "Y",
              legalName: options[:legal_name] || "Y",
              businessName: options[:business_name] || "Y"
            },
            postcode: options[:postcode],
            stateCode: {
              NSW: options[:states].include?("NSW") ? "Y" : "N",
              SA: options[:states].include?("SA") ? "Y" : "N",
              ACT: options[:states].include?("ACT") ? "Y" : "N",
              VIC: options[:states].include?("VIC") ? "Y" : "N",
              WA: options[:states].include?("WA") ? "Y" : "N",
              NT: options[:states].include?("NT") ? "Y" : "N",
              QLD: options[:states].include?("QLD") ? "Y" : "N",
              TAS: options[:states].include?("TAS") ? "Y" : "N"
            }
          },
          searchWidth: options[:search_width] || "Typical",
          minimumScore: options[:minimum_score] || 50,
          maxSearchResults: options[:max_search_results] || 10
        },
        authenticationGuid: @@guid
      }

      response = client.call(:abr_search_by_name_advanced2012, message: request)
      body = response.body[:abr_search_by_name_advanced2012_response]\
             [:abr_payload_search_results][:response]
      results = body[:search_results_list]

      if results.nil?
        fail "Exception: #{body[:exception][:exception_description]}"
      end

      abns = []
      results[:search_results_record].each do |r|
        abns << ABNSearch::Entity.new(abr_detail: r).update_from_abr!
      end
      abns
    end

    def self.check_guid
      new(@@guid).check_guid
    end

    def check_guid
      fail ArgumentError, "No GUID provided." if @@guid.nil?
      true
    end

    def self.validate_response(response, expected_first_symbol)
      if response.body[expected_first_symbol][:abr_payload_search_results]\
                  [:response][:business_entity201408].nil?
        return {
          result: :error,
          payload: response.body[expected_first_symbol]\
                   [:abr_payload_search_results][:response][:exception]
        }
      else
        return {
          result: :success,
          payload: response.body[expected_first_symbol]\
                   [:abr_payload_search_results][:response]\
                   [:business_entity201408]
        }
      end
    end
  end
end
