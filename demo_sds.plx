use "stdio"
m4_define(`_IMPL_SDS_M4', `')m4_dnl
m4_include(`sds.plx.m4')m4_dnl

pub fn main(none) i32 {
    s: sds = sds_new("Hello World ")
    s = sds_cat(s, "from a simple dynamic string!\n")
    print(s)
    sds_free(s)
    return 0
}
