#include "OblezComedyLines.h"

#define LOCTEXT_NAMESPACE "OblezComedyLines"

TArray<FText> UOblezComedyLines::GetManagerCalls()
{
	return {
		LOCTEXT("Mgr1", "وين التقرير؟! كان لازم يخلص من ساعة!"),
		LOCTEXT("Mgr2", "اجتماع طارئ بعد خمس دقايق، لا تتأخر."),
		LOCTEXT("Mgr3", "شفت إيميلي؟ رد عليه بسرعة."),
		LOCTEXT("Mgr4", "ليش النت عندك بطيء؟ أنا مو مشكلتي، خلص شغلك."),
		LOCTEXT("Mgr5", "وين وصلت بالملف؟ العميل يسأل عني كل شوي."),
		LOCTEXT("Mgr6", "لازم تجي مكتبي حالاً، فيه موضوع مهم."),
		LOCTEXT("Mgr7", "شكلك تعبان اليوم، سهرت؟ يلا ركّز بالشغل."),
		LOCTEXT("Mgr8", "نسيت توقّع المستند؟ ارجع وقّعه الحين."),
		LOCTEXT("Mgr9", "الاجتماع تأجل نص ساعة بس خله بالك حاضر."),
		LOCTEXT("Mgr10", "كم مرة أقولك رد على رسائلي بسرعة!"),
	};
}

TArray<FText> UOblezComedyLines::GetFamilyReactions()
{
	return {
		LOCTEXT("Fam1", "ليش لسا صاحي؟! بكرة عندك دوام!"),
		LOCTEXT("Fam2", "سكر هالجهاز ونام، الساعة توها ثلاث الفجر!"),
		LOCTEXT("Fam3", "قوم صلّي الفجر بدل ما تصيح على الشاشة."),
		LOCTEXT("Fam4", "شفناك قاعد باللاب توب من الصبح، وين الدراسة؟"),
		LOCTEXT("Fam5", "خلاص صار عندك زحمة ألعاب، ركّز شوي بحياتك."),
		LOCTEXT("Fam6", "يا ولد الجيران يبون يناموا، خفض صوتك شوي."),
		LOCTEXT("Fam7", "قلت لك مرة توقف عن اللعب وكل، الأكل برد."),
		LOCTEXT("Fam8", "شكلك ناسي إن عندك موعد بكرة الصبح."),
	};
}

TArray<FText> UOblezComedyLines::GetHypeComments()
{
	return {
		LOCTEXT("Hype1", "والله لعب نظيف!"),
		LOCTEXT("Hype2", "كومبو مجنون 🔥"),
		LOCTEXT("Hype3", "شكله بيتأهل هذا"),
		LOCTEXT("Hype4", "يا سلام على الدقة!"),
		LOCTEXT("Hype5", "هذا مو لعب هذا فن"),
		LOCTEXT("Hype6", "رد فعل سريع مره!"),
		LOCTEXT("Hype7", "اللاعب هذا مختلف"),
		LOCTEXT("Hype8", "كذا نبيه بالفريق"),
	};
}

TArray<FText> UOblezComedyLines::GetLagSpikeLines()
{
	return {
		LOCTEXT("Lag1", "تقطيع! ما سجلت الضغطة 😩"),
		LOCTEXT("Lag2", "البنق خذلك هالمرة!"),
		LOCTEXT("Lag3", "الراوتر قرر يسولف وياك بأسوأ توقيت."),
		LOCTEXT("Lag4", "لاق سبايك! لو عندك نت أحسن كانت انضربت."),
		LOCTEXT("Lag5", "الشبكة تهنّق عليك، لازم ترقية."),
	};
}

TArray<FText> UOblezComedyLines::GetLevelUpTaunts()
{
	return {
		LOCTEXT("LvlUp1", "شوي شوي وبتوصل EWC 😏"),
		LOCTEXT("LvlUp2", "من راوتر منزلي إلى نجم صاعد."),
		LOCTEXT("LvlUp3", "شكلك بديت تاخذ الموضوع بجد!"),
		LOCTEXT("LvlUp4", "ترقية! صار عندك احترام أكثر بالسيرفر."),
		LOCTEXT("LvlUp5", "خطوة جديدة نحو الاحتراف، كمّل كذا."),
	};
}

TArray<FText> UOblezComedyLines::GetRankDownTaunts()
{
	return {
		LOCTEXT("RankDown1", "ولا يهمك، حتى الأبطال يفوتون أهداف أحياناً."),
		LOCTEXT("RankDown2", "تراجع بسيط، ركّز أكثر بالجولة الجاية."),
		LOCTEXT("RankDown3", "يبدو إن اليوم مو يومك... حاول مرة ثانية."),
		LOCTEXT("RankDown4", "خسارة رانك؟ خذها بساطة وارجع أقوى."),
		LOCTEXT("RankDown5", "حتى الأسطورة يوم كان مبتدئ."),
	};
}

TArray<FText> UOblezComedyLines::GetFiredReasons()
{
	return {
		LOCTEXT("Fired1", "فُصلت من الشغل بعد ثلاث اتصالات متجاهلة! المدير ما صبر عليك أكثر."),
		LOCTEXT("Fired2", "المدير قال \"خلاص، ما فيه داعي ترجع بكرة\" — انفصلت رسمياً."),
		LOCTEXT("Fired3", "وصلك إيميل: \"نشكرك على جهودك\"... يعني انطردت بأدب."),
		LOCTEXT("Fired4", "ثلاث مرات تجاهلت المدير؟ اليوم تعلمت اللعب مو أهم شي بالحياة (بس تحاول)."),
	};
}

TArray<FText> UOblezComedyLines::GetKickedReasons()
{
	return {
		LOCTEXT("Kicked1", "خسرت 3 جولات رانك على التوالي... انطردت من الفريق! 😢"),
		LOCTEXT("Kicked2", "الفريق قرر يستبدلك بلاعب احتياطي... للأسف."),
		LOCTEXT("Kicked3", "الكابتن كتب بالقروب: \"ما نقدر نكمل وياك\"، وطلع من القروب."),
		LOCTEXT("Kicked4", "ثلاث خسائر متتالية = بطاقة حمراء من الفريق كامل."),
	};
}

FText UOblezComedyLines::RandomLine(const TArray<FText>& Lines)
{
	if (Lines.Num() == 0)
	{
		return FText::GetEmpty();
	}
	return Lines[FMath::RandHelper(Lines.Num())];
}

#undef LOCTEXT_NAMESPACE
