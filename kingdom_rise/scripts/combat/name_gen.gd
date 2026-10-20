class_name NameGen
extends RefCounted
## Random Warring-States style soldier names (surname + given name).

const SURNAMES := ["WANG", "LI", "ZHANG", "LIU", "CHEN", "YANG", "HUANG", "ZHOU", "WU", "XU", "SUN", "MA",
	"HU", "GUO", "LIN", "HE", "GAO", "LUO", "ZHENG", "LIANG", "XIE", "SONG", "TANG", "HAN", "FENG", "DENG",
	"CAO", "PENG", "XIAO", "TIAN", "DONG", "PAN", "YUAN", "CAI", "JIANG", "YU", "DU", "YE", "CHENG", "WEI",
	"SU", "LU", "DING", "REN", "SHEN", "YAO", "MENG", "BAI", "QIN", "KUANG", "BI", "TENG", "GAN", "LONG"]
const GIVEN := ["BAO", "CHENG", "DA", "FENG", "GANG", "HAO", "JIAN", "JUN", "KANG", "LEI", "LONG", "MING",
	"NING", "PENG", "QIANG", "RUI", "SHAN", "TAO", "WEI", "XIONG", "YAN", "YONG", "ZHAN", "ZHI", "HU", "BO",
	"KAI", "PING", "SHUN", "TIE", "GUI", "FU", "SHI", "WU", "YI", "HENG", "ZHAO", "DAN", "MO", "LIE", "SHOU",
	"QING", "PO", "GE", "BEN", "TU", "HAI", "SONG", "XIN", "YUE"]

static func make(_fac: int) -> String:
	return SURNAMES[randi() % SURNAMES.size()] + " " + GIVEN[randi() % GIVEN.size()]
