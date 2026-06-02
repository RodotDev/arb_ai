## Attempt 1
```shell
Development/modo_timer > dart run arb_ai --force

Starting arb_ai translation pipeline...
Source locale: en
Target languages: en-GB, en-US, pt-BR, pt-PT, pt, es-419, es-ES, es, fr-FR, fr, ru-RU, ru, uk-UK, uk
Translating 140 keys to "en-GB"...
⚠ Translation call failed: HttpException: Failed with status 400: {
  "error": {
    "code": 400,
    "message": "API key not valid. Please pass a valid API key.",
    "status": "INVALID_ARGUMENT",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "API_KEY_INVALID",
        "domain": "googleapis.com",
        "metadata": {
          "service": "generativelanguage.googleapis.com"
        }
      },
      {
        "@type": "type.googleapis.com/google.rpc.LocalizedMessage",
        "locale": "en-US",
        "message": "API key not valid. Please pass a valid API key."
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 400: {
  "error": {
    "code": 400,
    "message": "API key not valid. Please pass a valid API key.",
    "status": "INVALID_ARGUMENT",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "API_KEY_INVALID",
        "domain": "googleapis.com",
        "metadata": {
          "service": "generativelanguage.googleapis.com"
        }
      },
      {
        "@type": "type.googleapis.com/google.rpc.LocalizedMessage",
        "locale": "en-US",
        "message": "API key not valid. Please pass a valid API key."
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 4 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 3/3...
✗ Failed to translate batch 1/6 for "en-GB": HttpException: Failed with status 400: {
  "error": {
    "code": 400,
    "message": "API key not valid. Please pass a valid API key.",
    "status": "INVALID_ARGUMENT",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "API_KEY_INVALID",
        "domain": "googleapis.com",
        "metadata": {
          "service": "generativelanguage.googleapis.com"
        }
      },
      {
        "@type": "type.googleapis.com/google.rpc.LocalizedMessage",
        "locale": "en-US",
        "message": "API key not valid. Please pass a valid API key."
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent
Development/modo_timer > dart run arb_ai --force
Starting arb_ai translation pipeline...
Source locale: en
Target languages: en-GB, en-US, pt-BR, pt-PT, pt, es-419, es-ES, es, fr-FR, fr, ru-RU, ru, uk-UK, uk
Translating 140 keys to "en-GB"...
✔ Successfully wrote translations to "lib/l10n/app_en-GB.arb".
Translating 140 keys to "en-US"...
✔ Successfully wrote translations to "lib/l10n/app_en-US.arb".
Translating 140 keys to "pt-BR"...
⚠ Translation call failed: HttpException: Failed after 5 retries with status 429 (Too Many Requests). Last body: {
  "error": {
    "code": 429,
    "message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://ai.google.dev/gemini-api/docs/rate-limits. To monitor your current usage, head to: https://ai.dev/rate-limit. \n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 2.006230783s.",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.Help",
        "links": [
          {
            "description": "Learn more about Gemini API quotas",
            "url": "https://ai.google.dev/gemini-api/docs/rate-limits"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.QuotaFailure",
        "violations": [
          {
            "quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
            "quotaDimensions": {
              "model": "gemini-3.5-flash",
              "location": "global"
            },
            "quotaValue": "20"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay": "2s"
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
✔ Successfully wrote translations to "lib/l10n/app_pt-BR.arb".
Translating 140 keys to "pt-PT"...
⚠ Translation call failed: HttpException: Failed after 5 retries with status 429 (Too Many Requests). Last body: {
  "error": {
    "code": 429,
    "message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://ai.google.dev/gemini-api/docs/rate-limits. To monitor your current usage, head to: https://ai.dev/rate-limit. \n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 25.269988586s.",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.Help",
        "links": [
          {
            "description": "Learn more about Gemini API quotas",
            "url": "https://ai.google.dev/gemini-api/docs/rate-limits"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.QuotaFailure",
        "violations": [
          {
            "quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
            "quotaDimensions": {
              "model": "gemini-3.5-flash",
              "location": "global"
            },
            "quotaValue": "20"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay": "25s"
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed after 5 retries with status 429 (Too Many Requests). Last body: {
  "error": {
    "code": 429,
    "message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://ai.google.dev/gemini-api/docs/rate-limits. To monitor your current usage, head to: https://ai.dev/rate-limit. \n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 52.403706585s.",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.Help",
        "links": [
          {
            "description": "Learn more about Gemini API quotas",
            "url": "https://ai.google.dev/gemini-api/docs/rate-limits"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.QuotaFailure",
        "violations": [
          {
            "quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
            "quotaDimensions": {
              "location": "global",
              "model": "gemini-3.5-flash"
            },
            "quotaValue": "20"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay": "52s"
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 4 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 3/3...
⚠ Translation call failed: HttpException: Failed after 5 retries with status 429 (Too Many Requests). Last body: {
  "error": {
    "code": 429,
    "message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://ai.google.dev/gemini-api/docs/rate-limits. To monitor your current usage, head to: https://ai.dev/rate-limit. \n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 8.056005493s.",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.Help",
        "links": [
          {
            "description": "Learn more about Gemini API quotas",
            "url": "https://ai.google.dev/gemini-api/docs/rate-limits"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.QuotaFailure",
        "violations": [
          {
            "quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
            "quotaDimensions": {
              "location": "global",
              "model": "gemini-3.5-flash"
            },
            "quotaValue": "20"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay": "8s"
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed after 5 retries with status 429 (Too Many Requests). Last body: {
  "error": {
    "code": 429,
    "message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://ai.google.dev/gemini-api/docs/rate-limits. To monitor your current usage, head to: https://ai.dev/rate-limit. \n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 35.249096246s.",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.Help",
        "links": [
          {
            "description": "Learn more about Gemini API quotas",
            "url": "https://ai.google.dev/gemini-api/docs/rate-limits"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.QuotaFailure",
        "violations": [
          {
            "quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
            "quotaDimensions": {
              "model": "gemini-3.5-flash",
              "location": "global"
            },
            "quotaValue": "20"
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay": "35s"
      }
    ]
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 4 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 3/3...
```

## Attempt 2
```shell
Development/modo_timer > dart run arb_ai --force
Starting arb_ai translation pipeline...
Source locale: en
Target languages: en-GB, en-US, pt-BR, pt-PT, pt, es-419, es-ES, es, fr-FR, fr, ru-RU, ru, uk-UK, uk
Translating 140 keys to "en-GB"...
✔ Successfully wrote translations to "lib/l10n/app_en-GB.arb".
Translating 140 keys to "en-US"...
✔ Successfully wrote translations to "lib/l10n/app_en-US.arb".
Translating 140 keys to "pt-BR"...
✔ Successfully wrote translations to "lib/l10n/app_pt-BR.arb".
Translating 140 keys to "pt-PT"...
✔ Successfully wrote translations to "lib/l10n/app_pt-PT.arb".
Translating 140 keys to "pt"...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
✔ Successfully wrote translations to "lib/l10n/app_pt.arb".
Translating 140 keys to "es-419"...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 4 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 3/3...
✗ Failed to translate batch 13/14 for "es-419": HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent
Development/modo_timer > dart run arb_ai        
Starting arb_ai translation pipeline...
Source locale: en
Target languages: en-GB, en-US, pt-BR, pt-PT, pt, es-419, es-ES, es, fr-FR, fr, ru-RU, ru, uk-UK, uk
Translating 140 keys to "en-GB"...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent. Retrying in 4 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 3/3...
✗ Failed to translate batch 7/14 for "en-GB": HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent
```


## Attempt 3 (with gemini-2.5-flash)
```shell
Development/modo_timer > dart run arb_ai --force
Starting arb_ai translation pipeline...
Source locale: en
Target languages: en-GB, en-US, pt-BR, pt-PT, pt, es-419, es-ES, es, fr-FR, fr, ru-RU, ru, uk-UK, uk
Translating 140 keys to "en-GB"...
✔ Successfully wrote translations to "lib/l10n/app_en-GB.arb".
Translating 140 keys to "en-US"...
✔ Successfully wrote translations to "lib/l10n/app_en-US.arb".
Translating 140 keys to "pt-BR"...
✔ Successfully wrote translations to "lib/l10n/app_pt-BR.arb".
Translating 140 keys to "pt-PT"...
⚠ Translation call failed: HttpException: Failed with status 503: {
  "error": {
    "code": 503,
    "message": "This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.",
    "status": "UNAVAILABLE"
  }
}
, uri = https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent. Retrying in 2 seconds...
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
✔ Successfully wrote translations to "lib/l10n/app_pt-PT.arb".
Translating 140 keys to "pt"...
✔ Successfully wrote translations to "lib/l10n/app_pt.arb".
Translating 140 keys to "es-419"...
✔ Successfully wrote translations to "lib/l10n/app_es-419.arb".
Translating 140 keys to "es-ES"...
✔ Successfully wrote translations to "lib/l10n/app_es-ES.arb".
Translating 140 keys to "es"...
✔ Successfully wrote translations to "lib/l10n/app_es.arb".
Translating 140 keys to "fr-FR"...
✔ Successfully wrote translations to "lib/l10n/app_fr-FR.arb".
Translating 140 keys to "fr"...
✔ Successfully wrote translations to "lib/l10n/app_fr.arb".
Translating 140 keys to "ru-RU"...
✔ Successfully wrote translations to "lib/l10n/app_ru-RU.arb".
Translating 140 keys to "ru"...
⚠ ICU validation failed for key "cyclesValue": Missing required CLDR plural categories for language "ru": one, few, many
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
✔ Successfully wrote translations to "lib/l10n/app_ru.arb".
Translating 140 keys to "uk-UK"...
✔ Successfully wrote translations to "lib/l10n/app_uk-UK.arb".
Translating 140 keys to "uk"...
⚠ ICU validation failed for key "cyclesValue": Missing required CLDR plural categories for language "uk": one, few, many
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 2/3...
⚠ ICU validation failed for key "cyclesValue": Missing required CLDR plural categories for language "uk": one, few, many
⚠ ICU validation failed or API failed for some keys. Retrying translation attempt 3/3...
⚠ ICU validation failed for key "cyclesValue": Missing required CLDR plural categories for language "uk": one, few, many
✗ Failed to translate batch 3/6 for "uk": FormatException: ICU validation failed after 3 attempts for keys: cyclesValue
```