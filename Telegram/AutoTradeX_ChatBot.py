from telegram import Update
from telegram.ext import (
    ApplicationBuilder,
    ChatMemberHandler,
    CommandHandler,
    ContextTypes,
)

TOKEN = '8109360487:AAHw87Xb2zTzQ96Enax1Kgtyu1UKlluyc4U'
URL_SITE = 'https://www.autotradex.com.br'
URL_PRODUTOS = 'https://www.autotradex.com.br/produtos'
URL_CONFIGURACOES = 'https://www.autotradex.com.br/configuracoes'

# Boas-vindas ao novo membro
async def welcome(update: Update, context: ContextTypes.DEFAULT_TYPE):
    for member in update.chat_member.new_chat_members:
        msg = (
            f"Bem-vindo(a), {member.full_name}! 🎉\n"
            f"Conheça nosso site: {URL_SITE}\n\n"
            f"Digite /produtos para conhecer nossos produtos\n"
            f"Ou /configuracoes para saber como configurar nossos dispositivos."
        )
        await context.bot.send_message(chat_id=update.chat_member.chat.id, text=msg)

# Comando: /produtos
async def produtos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        f"Confira nossos produtos neste link: {URL_PRODUTOS}"
    )

# Comando: /configuracoes
async def configuracoes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        f"Veja como configurar nossos produtos aqui: {URL_CONFIGURACOES}"
    )

if __name__ == '__main__':
    app = ApplicationBuilder().token(TOKEN).build()

    # Handler para boas-vindas
    app.add_handler(ChatMemberHandler(welcome, ChatMemberHandler.CHAT_MEMBER))

    # Handlers para comandos
    app.add_handler(CommandHandler("produtos", produtos))
    app.add_handler(CommandHandler("configuracoes", configuracoes))

    print("Bot rodando...")
    app.run_polling()
