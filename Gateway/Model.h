class Garden
{
private:
  float nhietdo;
  float doam;
  float doamdat;
  bool pump;
  bool fan;
  bool light;
  bool mode;
public:
  Garden(float nhietdo, float doam, float doamdat, bool pump, bool fan, bool light, bool mode){
    this->nhietdo = nhietdo;
    this->doam = doam;
    this->doamdat = doamdat;
    this->fan = fan;
    this->light = light;
    this->pump = pump;
    this->mode = mode;
  }

  void setNhietDo(float nhietdo){
    this->nhietdo = nhietdo;
  }

  void setDoAm(float doam){
    this->doam = doam;
  }

  void setDoAmDat(float doamdat){
    this->doamdat = doamdat;
  }

  void setFan(const String &fanString)   { fan   = fanString.equals("1"); }
  void setLight(const String &lightString){ light = lightString.equals("1"); }
  void setPump(const String &pumpString) { pump  = pumpString.equals("1"); }
  void setMode(const String &modeString) { mode  = modeString.equals("1"); }


  float getNhietDo(){
    return nhietdo;
  }

  float getDoAm(){
    return doam;
  }

  float getDoAmDat(){
    return doamdat;
  }

  bool getLight(){
    return light;
  }

  bool getPump(){
    return pump;
  }

  bool getFan(){
    return fan;
  }

  bool getMode(){
    return mode;
  }

  void hienthi(){
    Serial.print("   Mode: ");
    Serial.println(mode == 1?"Manual":"   Auto");
    Serial.print("   Nhiet do: ");
    Serial.println(nhietdo);
    Serial.print("   Do am: ");
    Serial.println(doam);
    Serial.print("   Do am dat: ");
    Serial.println(doamdat);
    Serial.print("   Pump:");
    Serial.println(pump);
    Serial.print("   Fan: ");
    Serial.println(fan);
    Serial.print("   Light: ");
    Serial.println(light);
  }
};

class  Gate
{
private:
  bool chedo;
  bool maybom;
  float docao;
public:
   Gate(bool chedo,bool maybom, float docao){
     this->chedo = chedo;
     this->maybom = maybom;
     this->docao = docao;
   };

   void setCheDo(String chedoString){
     if(chedoString == "1"){
       this->chedo = 1;
     }
     else{
       this->chedo = 0;
     }
   }

   void setMayBom(String maybomString){
     if(maybomString == "1"){
       this->maybom = 1;
     }
     else{
       this->maybom = 0;
     }
   }

   void setDoCao(float docao){
     this->docao = docao;
   }

   bool getCheDo(){
     return chedo;
   }

   bool getMayBom(){
     return maybom;
   }

   float getDoCao(){
     return docao;
   }

   void hienthi(){
     Serial.println("---Gate---");
     Serial.print("   Che do: ");
     Serial.println(chedo == 1? "   Manual":"   Auto");
     Serial.print("   May bom: ");
     Serial.println(maybom);
     Serial.print("   Do cao: ");
     Serial.println(docao);
     Serial.println("=================================");
   }
};
