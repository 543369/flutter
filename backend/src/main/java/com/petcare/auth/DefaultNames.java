package com.petcare.auth;

import java.util.Locale;
import java.util.concurrent.ThreadLocalRandom;

/** Device locale is a naming preference, not a claim about the user's location. */
public final class DefaultNames {
 private DefaultNames() {}
 public static String forLocale(String tag) {
  Locale locale=Locale.forLanguageTag(tag==null?"zh-CN":tag.replace('_','-'));
  String[] names=switch(locale.getLanguage()) {
   case "zh" -> ("TW".equals(locale.getCountry()) || "HK".equals(locale.getCountry()))
     ? new String[]{"暖陽","小橘","棉花糖","星星","小圓"}
     : new String[]{"暖阳","小橘","棉花糖","星星","小圆"};
   case "ja" -> new String[]{"そら","はる","ひなた","こむぎ"};
   case "ko" -> new String[]{"하늘","봄","구름","별"};
   default -> new String[]{"Sunny","Clover","Maple","Robin","River"};
  };
  var random=ThreadLocalRandom.current();
  return names[random.nextInt(names.length)]+random.nextInt(1000,10000);
 }
}
