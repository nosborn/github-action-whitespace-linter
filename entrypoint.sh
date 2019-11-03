#!/bin/sh

lint() {
  awk '
    function report_blank(first, last) {
      if (first == last) {
        print "  " first ": superfluous blank line"
      } else {
        print "  " first "-" last ": superfluous blank lines"
      }
    }

    function report_trailing(line) {
      print "  " line ": trailing whitespace"
    }

    BEGIN {
      first_blank = 1
      last_blank = 0
    }

    NF == 0 {
      if (first_blank == 0) {
        first_blank = NR
      } else {
        last_blank = NR
      }
    }

    NF > 0 {
      if (last_blank > 0) {
        if (first_blank > 1) {
          first_blank += 1
        }
        report_blank(first_blank, last_blank)
      }
      first_blank = last_blank = 0
    }

    /[[:space:]]$/ {
      report_trailing(NR)
    }

    END {
      if (first_blank > 0) {
        if (last_blank == 0) {
          last_blank = first_blank
        }
        report_blank(first_blank, last_blank)
      }
    }
  ' "${1}"
}

comment=""
status=0

for file in ${INPUT_FILES}; do
  OUTPUT=$(lint "${file}")

  if [ -z "${OUTPUT}" ]; then
    continue
  fi
  echo "${file}:"
  echo "${OUTPUT}"
  status=1

  comment="${comment}<details><summary><code>${file}</code></summary>

\`\`\`
${OUTPUT}
\`\`\`

</details>"
done

if [ ${status} -eq 0 ]; then
  exit 0
fi

if [ "${GITHUB_EVENT_NAME}" = pull_request ]; then
  COMMENT_BODY="#### Issues with whitespace
${comment}

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`*"
  PAYLOAD=$(echo '{}' | jq --arg body "${COMMENT_BODY}" '.body = $body')
  COMMENTS_URL=$(jq -r .pull_request.comments_url <"${GITHUB_EVENT_PATH}")

  curl -sS \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "${PAYLOAD}" \
    "${COMMENTS_URL}" >/dev/null
fi

exit ${status}
