module UnionpayLib
  class Service < Base
    attr_accessor :args, :api_url

    def self.default_options
      options = {
          'version' => '5.0.0',
          'encoding' => 'utf-8',
          'txnType' => '01',
          'txnSubType' => '01',
          'bizType' => '000201',
          'signMethod' => '01',
          'channelType' => '07',
          'accessType' => '0',
          'currencyCode' => '156'
          'txnTime': Time.now.strftime("%Y%m%d%H%M%S"),
          'certId': @@pkcs12.certificate.serial.to_s,
          'merId': @@merchant_no 
      }
    end

    def self.front_pay(param)
      options = default_options
      new.instance_eval do
        param = param.merge!(options)
        trans_type = param['txnType']
        if ["01", "02"].include? trans_type
          @api_url = UnionPay.front_pay_url
          self.args = param
          @param_check = UnionPay::PayParamsCheck
        else
          # 前台交易仅支持 消费 和 预授权
          raise("Bad trans_type for front_pay. Use back_pay instead")
        end
        service
      end
    end

    def self.back_pay(param)
      new.instance_eval do
        param['orderTime']         ||= Time.now.strftime('%Y%m%d%H%M%S')         #交易时间, YYYYmmhhddHHMMSS
        param['orderCurrency']     ||= '156'
        param['transType']         ||= '04'
        param['merId'] = UnionpayLiby.merId
        @api_url = UnionpayLib.back_pay_url
        trans_type = param['transType']
        if ['01', '02'].include? trans_type
          if !self.args['cardNumber'] && !self.args['pan']
            raise('consume OR pre_auth transactions need cardNumber!')
          end
        else
          raise('origQid is not provided') 
        end
        service
      end
    end

    def self.query(param)
      new.instance_eval do
        @api_url = UnionpayLiby.query_url
        param['version'] = '5.0.0'
        param['charset'] = 'UTF-8'
        param['merId'] = UnionpayLiby.merId

        if empty?(UnionpayLib['merId']) && mpty?(UnionpayLib['acqCode'])
          raise('merId and acqCode can\'t be both empty')
        end
        if empty?(UnionpayLib['acqCode'])
          acq_code = UnionpayLib['acqCode']
          param['merReserved'] = "{acqCode=#{acq_code}}"
        else
          param['merReserved'] = ''
        end

        self.args = param
        service
      end
    end

    private
    def service
      self.args = self.args.symbolize_keys!
      self.args = convert_params(self.args)
      self.args[:signature] = sign(self.args)
      self.args['signMethod'] = '01'
      return self.args if block_given?

      response = faraday.post(path, self.args)
      result = response.body
      result
    end

    def convert_params(param)
      sign_str = param.map do |k, v|
        "#{k}=#{v}"
      end.join("&").strip
    end

    def empty? str
      str !~ /[^[:space:]]/
    end
  end
end
