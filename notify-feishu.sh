#!/bin/sh
set -e

# 依赖 CI 注入的环境变量：
#   SERVICE_NAME, BUILD_SH, FEISHU_BOT_WEBHOOK
#   CI_COMMIT_REF_NAME, CI_PIPELINE_URL, GITLAB_USER_NAME
#   ARGO_BASE_URL（可选）
#   以及 build 产物 timestamp.env（可选）

if [ -z "${SERVICE_NAME:-}" ]; then
  echo "SERVICE_NAME 未设置"
  exit 1
fi

if [ -z "${FEISHU_BOT_WEBHOOK:-}" ]; then
  echo "FEISHU_BOT_WEBHOOK 未配置，跳过飞书通知"
  exit 0
fi

ARGO_BASE_URL="${ARGO_BASE_URL:-https://cd.molardata.com/applications/argocd}"

get_env_emoji() {
  case "$1" in
    prod)  echo "🔴" ;;
    pre)   echo "🟡" ;;
    daily) echo "🟢" ;;
    *)     echo "⚪" ;;
  esac
}

get_argo_link() {
  # $1 = BUILD_SH
  argo_id=""
  base="${ARGO_BASE_URL}"
  query="?view=tree&resource="
  case "$1" in
    daily) argo_id="volc-daily-${SERVICE_NAME}" ;;
    pre)   argo_id="aws-pre-${SERVICE_NAME}" ;;
    prod)  argo_id="aws-prod-${SERVICE_NAME}" ;;
  esac
  if [ -n "$argo_id" ]; then
    echo "${base}/${argo_id}${query}"
  fi
}

ENV_EMOJI=$(get_env_emoji "$BUILD_SH")

ARGO_INFO=""
LINK=$(get_argo_link "$BUILD_SH")
if [ -n "$LINK" ]; then
  ARGO_INFO="\n🚀 Argo链接: ${LINK}"
fi

IMAGE_INFO=""
if [ -f timestamp.env ]; then
  TIMESTAMP=$(grep '^TIMESTAMP=' timestamp.env | cut -d= -f2)
  if [ -n "$TIMESTAMP" ]; then
    IMAGE_INFO="\n📦 镜像号: ${TIMESTAMP}"
  fi
fi

MSG="🎉 项目 [${SERVICE_NAME}] 构建完成"
MSG="${MSG}\n${ENV_EMOJI} 环境: ${BUILD_SH}"
MSG="${MSG}${IMAGE_INFO}"
MSG="${MSG}\n📍 分支: ${CI_COMMIT_REF_NAME}${ARGO_INFO}"
MSG="${MSG}\n🔗 详情: ${CI_PIPELINE_URL}"
MSG="${MSG}\n👤 操作人: ${GITLAB_USER_NAME}"

curl -sS -X POST -H "Content-Type: application/json" \
  -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"${MSG}\"}}" \
  "$FEISHU_BOT_WEBHOOK"
