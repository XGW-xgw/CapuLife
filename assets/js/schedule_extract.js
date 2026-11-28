/**
 * 旧版 CapuLife 的教务课表提取脚本（从 WebVPN 内的教务课表页面 DOM 中提取）。
 *
 * 这段函数会被原样注入到 WebView 中执行：它把提取结果分片写入 document.title，
 * 原生层通过 titleUpdate 收集 `__CAP_CHUNK__:` / `__CAP_SCHEDULE__:` 协议。
 * 不要把它改成依赖外部变量；它必须保持自包含。
 */function scheduleExtract() {
            var capSkips = [];
            var e = !1,
                t = [],
                o = null,
                r = "";

            function n(t) {
                if (!e) {
                    e = !0;
                    var o = document.title || "",
                        r = "";
                    try {
                        r = JSON.stringify(t)
                    } catch (c) {
                        return
                    }
                    var n = "";
                    try {
                        n = btoa(unescape(encodeURIComponent(r)))
                    } catch (c) {
                        try {
                            var a = "__CAP_SCHEDULE__:" + Date.now() + ":" + r;
                            document.title = a, setTimeout((function() {
                                document.title === a && (document.title = o)
                            }), 700)
                        } catch (d) {}
                        return
                    }
                    var l = Math.ceil(n.length / 700) || 1,
                        s = "m" + Date.now().toString(36),
                        i = 0;
                    ! function e() {
                        if (i >= l) setTimeout((function() {
                            0 === String(document.title || "").indexOf("__CAP_CHUNK__:") && (document.title = o)
                        }), 400);
                        else {
                            var t = n.slice(700 * i, 700 * (i + 1));
                            document.title = "__CAP_CHUNK__:" + s + ":" + i + ":" + l + ":" + t, i++, setTimeout(e, 55)
                        }
                    }()
                }
            }

            function a(e) {
                return String(e || "").replace(/\d{6,}/g, "***")
            }

            function l(e) {
                for (var t = String(e || "").split(/\r?\n/), o = [], r = 0; r < t.length; r++) {
                    var n = t[r].replace(/\s+/g, " ").trim();
                    n && o.push(n)
                }
                return o
            }

            function s(e) {
                if (!e) return !1;
                var t = String(e).trim();
                return !(t.length < 2 || t.length > 40) && (!(/^\d{4}-\d{4}/.test(t) || /^[01]{5,}$/.test(t) || /^第?\d+[-~至]\d+周/.test(t)) && /(楼|室|馆|场|实训|中心|机房|栋|厅|阶|教|基地|机库|操场|体育|广场|学院|校区|东区|西区|南区|北区|[A-Za-z]-?\d{2,4}|\d{3,4})/.test(t))
            }

            function i(e) {
                if (!e) return !1;
                var t = String(e).trim();
                return !!/^[01]{8,30}$/.test(t) || /(\d+\s*[-~至到]\s*\d+\s*周?|第?\d+\s*周|单周|双周|\d+[,，、]\d+)/.test(t) && /周|单|双|[-~至]/.test(t)
            }

            function c(e, t) {
                var o = String(e || "").trim(),
                    r = String(t || "").trim();
                return o ? r ? r.indexOf(o) >= 0 ? r : o.indexOf(r) >= 0 ? o : o + " " + r : o : r
            }

            function d(e, t, o) {
                var r = e.JXLMC || e.jxlmc || e.buildingName || e.buildName || e.JXL || e.jxl || e.JXLDM_DISPLAY || e.XQMC || e.campusName || "",
                    n = e.JASMC || e.jasmc || e.placeName || e.classroomName || e.classroom || e.JSMC || e.jsmc || e.CDMC || e.cdmc || e.JXDD || e.jxdd || e.SKDD || e.skdd || e.JXCDMC || e.jxcdmc || e.DDMC || e.ddmc || e.roomName || e.room || e.place || e.address || e.location || "";
                if (n) return c(r, n);
                if (Array.isArray(e.titleDetail) && e.titleDetail.length > 0) {
                    for (var a = 1; a < e.titleDetail.length; a++) {
                        var l = String(e.titleDetail[a] || "").trim();
                        if (l && l !== t && l !== o && s(l)) return c(r, l)
                    }
                    var d = String(e.titleDetail[e.titleDetail.length - 1] || "").trim();
                    if (d && d !== t && d !== o && !i(d)) return c(r, d)
                }
                var u = e.YPSJDD || e.ypsjdd || e.SKSJDD || e.sksjdd || e.arrangeInfo || "";
                if (u)
                    for (var m = String(u).split(/[\s,，;；/]+/), h = m.length - 1; h >= 0; h--)
                        if (s(m[h])) return c(r, m[h]);
                for (var p = Object.keys(e), y = {
                        KCM: 1,
                        courseName: 1,
                        KCMC: 1,
                        name: 1,
                        SKJS: 1,
                        teacherName: 1,
                        teachers: 1,
                        JSXM: 1,
                        SKZC: 1,
                        ZCMC: 1,
                        XNXQDM: 1,
                        termCode: 1,
                        KCH: 1,
                        JXBID: 1,
                        JXBH: 1,
                        WID: 1,
                        id: 1,
                        BJMC: 1,
                        JXBMC: 1,
                        className: 1,
                        weeksAndTeachers: 1
                    }, g = 0; g < p.length; g++) {
                    var f = p[g];
                    if (!y[f]) {
                        var v = e[f];
                        if ("string" == typeof v && v !== t && v !== o && /(place|room|jas|jsmc|dd|cdmc|bldg|build|jxl|loc|addr)/i.test(f) && v.trim().length >= 2) return c(r, v.trim())
                    }
                }
                for (var w = 0; w < p.length; w++) {
                    var b = p[w];
                    if (!y[b]) {
                        var S = e[b];
                        if ("string" == typeof S && S !== t && S !== o && s(S)) return c(r, S.trim())
                    }
                }
                return String(r || "").trim()
            }

            function u(e) {
                var t = [],
                    o = 1,
                    r = 18,
                    n = 0;
                if (Array.isArray(e) && e.length > 0)
                    for (var a = 0; a < e.length; a++) {
                        var l = parseInt(e[a], 10);
                        l >= 1 && l <= 30 && t.indexOf(l) < 0 && t.push(l)
                    } else if ("string" == typeof e) {
                        var s = e.trim();
                        if (/^[01]{8,30}$/.test(s))
                            for (var i = 0; i < s.length; i++) "1" === s.charAt(i) && t.push(i + 1);
                        else {
                            var c = s.replace(/第?\s*\d+\s*[-~至到]\s*\d+\s*节/g, " ").replace(/第?\s*\d+\s*节/g, " ").replace(/\d{4}\s*-\s*\d{4}(-\d)?/g, " "),
                                d = 0;
                            /[(（]?单周?[)）]?/.test(c) && !/双/.test(c) ? d = 1 : /[(（]?双周?[)）]?/.test(c) && !/单/.test(c) && (d = 2);
                            for (var u = c.split(/[,，、;；]+/), m = 0; m < u.length; m++) {
                                var h = u[m].trim();
                                if (h) {
                                    var p = /单/.test(h) ? 1 : /双/.test(h) ? 2 : d,
                                        y = h.match(/(\d+)\s*[-~至到]\s*(\d+)/);
                                    if (y) {
                                        var g = parseInt(y[1], 10),
                                            f = parseInt(y[2], 10);
                                        if (g >= 1 && f >= g && f <= 30)
                                            for (var v = g; v <= f; v++) 1 === p && v % 2 == 0 || 2 === p && v % 2 != 0 || t.indexOf(v) < 0 && t.push(v)
                                    } else {
                                        var w = h.match(/^第?\s*(\d{1,2})\s*周?(\([单双]\))?$/);
                                        if (w || (w = h.match(/第?\s*(\d{1,2})\s*周/)), w) {
                                            var b = parseInt(w[1], 10);
                                            b >= 1 && b <= 30 && t.indexOf(b) < 0 && t.push(b)
                                        }
                                    }
                                }
                            }
                            n = d
                        }
                    } return t.length > 0 && (t.sort((function(e, t) {
                    return e - t
                })), o = t[0], r = t[t.length - 1]), {
                    weeks: t,
                    startWeek: o,
                    endWeek: r,
                    oddEven: n
                }
            }

            function m(e) {
                for (var t = [e.week, e.SKZC, e.skzc, e.ZCBH, e.zcbh, e.weekBit, e.weeksBit], o = 0; o < t.length; o++) {
                    var r = t[o];
                    if ("string" == typeof r && /^[01]{8,30}$/.test(r.trim())) {
                        var n = u(r);
                        if (n.weeks.length > 0) return n
                    }
                }
                for (var a = Object.keys(e || {}), l = 0; l < a.length; l++) {
                    var s = e[a[l]];
                    if ("string" == typeof s && /^[01]{12,30}$/.test(s.trim())) {
                        var c = u(s);
                        if (c.weeks.length > 0) return c
                    }
                }
                for (var d = [e.weekList, e.weeks, e.ZCMC, e.zcmc, e.SKZCMC, e.skzcmc, e.ZC, e.zc, e.weekStr, e.weekText, e.weekRange, e.weeksAndTeachers, e.YPSJDD, e.ypsjdd, e.SKSJDD, e.sksjdd], m = 0; m < d.length; m++) {
                    var h = d[m];
                    if (h) {
                        var p = u(h);
                        if (p.weeks.length > 0) return p
                    }
                }
                if (Array.isArray(e.titleDetail))
                    for (var y = 0; y < e.titleDetail.length; y++) {
                        var g = String(e.titleDetail[y] || "").trim();
                        if (g && i(g)) {
                            var f = u(g);
                            if (f.weeks.length > 0) return f
                        }
                    }
                for (var v = 0; v < a.length; v++) {
                    var w = e[a[v]];
                    if ("string" == typeof w && w.indexOf("周") >= 0 && w.length < 60) {
                        var b = u(w);
                        if (b.weeks.length > 0) return b
                    }
                }
                return {
                    weeks: [],
                    startWeek: 1,
                    endWeek: 18,
                    oddEven: 0
                }
            }

            function h(e) {
                var t = e.match(/(\d+)\s*[-~至到]\s*(\d+)\s*节/);
                if (t) {
                    var o = parseInt(t[1], 10) || 1,
                        r = parseInt(t[2], 10) || o + 1;
                    return {
                        start: o,
                        span: Math.max(r - o + 1, 1)
                    }
                }
                var n = e.match(/第?\s*(\d+)\s*节/);
                return n ? {
                    start: parseInt(n[1], 10) || 1,
                    span: 2
                } : null
            }

            function p(e, t, o, r, n, a, l, s) {
                var i = {
                    n: String(e || "").replace(/\[.*?\]/g, "").trim().slice(0, 48),
                    t: String(t || "").trim().slice(0, 18),
                    r: String(o || "").trim().slice(0, 30),
                    d: Math.min(Math.max(parseInt(r, 10) || 1, 1), 7),
                    s: Math.min(Math.max(parseInt(n, 10) || 1, 1), 12),
                    p: Math.min(Math.max(parseInt(a, 10) || 2, 1), 8),
                    sw: l.startWeek || 1,
                    ew: l.endWeek || 18,
                    oe: l.oddEven || 0
                };
                return l.weeks && l.weeks.length > 0 && (i.w = l.weeks), s && s.start && (i.st = s.start), s && s.end && (i.et = s.end), i
            }

            function y(e) {
                for (var t = {}, o = [], r = 0; r < e.length; r++) {
                    var n = e[r];
                    if (n.n) {
                        var a = [n.n, n.d, n.s, n.p, n.r, n.w ? n.w.join(",") : n.sw + "-" + n.ew + "-" + n.oe].join("|");
                        t[a] || (t[a] = !0, o.push(n))
                    }
                }
                return o
            }

            function g(e) {
                var t = String(null == e ? "" : e).trim();
                if (!t) return 0;
                var o = t.match(/(\d{1,2})\s*[-~至到]\s*(\d{1,2})/);
                if (o) return parseInt(o[1], 10) || 0;
                var r = t.replace(/[^\d]/g, "");
                return r ? r.length >= 4 ? parseInt(r.slice(0, 2), 10) || 0 : parseInt(r, 10) || 0 : 0
            }

            function f(e) {
                var t = String(null == e ? "" : e).trim();
                if (!t) return 0;
                var o = t.match(/(\d{1,2})\s*[-~至到]\s*(\d{1,2})/);
                if (o) return parseInt(o[2], 10) || 0;
                var r = t.replace(/[^\d]/g, "");
                return r ? r.length >= 4 ? parseInt(r.slice(-2), 10) || 0 : parseInt(r, 10) || 0 : 0
            }

            function v(e) {
                var t = Number(e) || 0;
                return t <= 4 ? t : 5 === t ? 4 : t <= 9 ? t - 1 : 10 === t ? 8 : t - 2
            }

            function w(e, t) {
                if (!e) return "";
                for (var o = 0; o < t.length; o++) {
                    var r = e[t[o]];
                    if (null != r) {
                        var n = String(r).match(/(\d{1,2}):(\d{2})/);
                        if (n) {
                            var a = parseInt(n[1], 10);
                            if (a >= 0 && a <= 23) return (a < 10 ? "0" + a : String(a)) + ":" + n[2]
                        }
                    }
                }
                return ""
            }

            function b(e, t) {
                var r = null;
                if (!e) return [];
                if (e.datas ? e.datas.xskcb && Array.isArray(e.datas.xskcb.rows) ? r = e.datas.xskcb.rows : e.datas.cxxszhxqkb && Array.isArray(e.datas.cxxszhxqkb.rows) ? r = e.datas.cxxszhxqkb.rows : Array.isArray(e.datas.arrangedList) ? r = e.datas.arrangedList : Array.isArray(e.datas.rows) ? r = e.datas.rows : Array.isArray(e.datas) && (r = e.datas) : Array.isArray(e.rows) ? r = e.rows : Array.isArray(e) && (r = e), !r || 0 === r.length) return [];
                !o && r[0] && "object" == typeof r[0] && (o = function(e) {
                    for (var t = {}, o = Object.keys(e || {}), r = 0; r < o.length && r < 28; r++) {
                        var n = o[r],
                            l = e[n];
                        null != l && "" !== l && ("string" == typeof l ? t[n] = /^[01]{8,30}$/.test(l) ? l : a(l).slice(0, 48) : "number" == typeof l || "boolean" == typeof l ? t[n] = l : Array.isArray(l) && (t[n] = l.slice(0, 6).map((function(e) {
                            return a(String(e)).slice(0, 32)
                        }))))
                    }
                    return t
                }(r[0]));
                for (var n = 0, l = 0; l < r.length; l++) {
                    var s = r[l];
                    if (s && "object" == typeof s) {
                        var i = g(s.KSJC || s.ksjc || s.beginSection || s.startSection || s.SKJC || s.skjc || 0),
                            c = f(s.JSJC || s.jsjc || s.endSection || s.JSJS || s.jsjs || 0);
                        i > n && (n = i), c > n && (n = c)
                    }
                }
                for (var u = t && t.length ? t.length : 0, h = Boolean(u && n > u), b = [], S = 0; S < r.length; S++) {
                    var k = r[S];
                    if (k && "object" == typeof k) {
                        var x = k.KCM || k.courseName || k.kcm || k.KCMC || k.name || "",
                            E = k.SKXQ || k.dayOfWeek || k.skxq || k.XQ || k.day || 0,
                            N = k.KSJC || k.ksjc || k.beginSection || k.startSection || k.SKJC || k.skjc || 0,
                            C = k.JSJC || k.jsjc || k.endSection || k.JSJS || k.jsjs || 0,
                            V = k.SKJS || k.teacherName || k.teachers || k.skjs || k.JSXM || "";
                        !x && Array.isArray(k.titleDetail) && k.titleDetail.length > 0 && (x = k.titleDetail[0] || ""), !V && k.weeksAndTeachers && (V = String(k.weeksAndTeachers).replace(/\d+\s*[-~至]\s*\d+\s*周(\([单双]\))?/g, "").trim()), Array.isArray(V) && (V = V.map((function(e) {
                            return "object" == typeof e ? e.name || e.XM || "" : String(e)
                        })).join(","));
                        var T = d(k, x, V),
                            B = m(k),
                            D = parseInt(E, 10),
                            M = g(N),
                            A = f(C);
                        if (x && D && M) {
                            h && (M = v(M), A && (A = v(A)));
                            var I = t && t.length ? Number(t[t.length - 1].num) : 12;
                            M > I && (M = I);
                            var _ = A >= M ? A - M + 1 : 2,
                                P = z(t, M),
                                F = z(t, M + _ - 1),
                                R = w(k, ["beginTime", "KSSJ", "kssj", "QSSJ", "qssj", "startTime", "start_time", "SKSSJ"]),
                                L = w(k, ["JSSJ", "jssj", "JSSJ", "endTime", "end_time", "SJSSJ"]);
                            b.push(p(x, V, T, D, M, _, B, {
                                start: R || (P ? P.start : ""),
                                end: L || (F ? F.end : P ? P.end : "")
                            }))
                        } else {
                            // 字段不全被丢弃：计进收集器，让用户知道有多少条课因缺字段没进课表。
                            capSkips.push({ n: String(x || "").slice(0, 24), why: x ? (D ? "jc" : "xq") : "name" })
                        }
                    }
                }
                return y(b)
            }

            function S(e, t, o, r) {
                try {
                    var n = new XMLHttpRequest;
                    n.open(e, t, !0), n.withCredentials = !0, n.timeout = 4500, "POST" === e && n.setRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8"), n.setRequestHeader("X-Requested-With", "XMLHttpRequest"), n.onreadystatechange = function() {
                        4 === n.readyState && r(n.status, n.responseText || "")
                    }, n.onerror = function() {
                        r(0, "")
                    }, n.ontimeout = function() {
                        r(0, "")
                    }, n.send(o || null)
                } catch (a) {
                    r(0, "")
                }
            }

            function k(e) {
                try {
                    return JSON.parse(e)
                } catch (t) {
                    return null
                }
            }

            function x(e) {
                if (!e) return null;
                var t = e.cells && e.cells.length > 0 ? e.cells[0] : null,
                    o = t && (t.innerText || t.textContent) || "";
                if (!(o = String(o).replace(/\s+/g, " ").trim())) return null;
                var r = o.match(/第\s*(\d{1,2})\s*节/);
                return r ? {
                    num: parseInt(r[1], 10),
                    isBreak: !1
                } : /午餐|晚餐|午休|休息|课间/.test(o) ? {
                    num: 0,
                    isBreak: !0
                } : null
            }

            function E(e) {
                var t = [];
                if (!e || !e.rows) return t;
                for (var o = 0, r = 0; r < e.rows.length; r++) {
                    var n = x(e.rows[r]);
                    n && n.num > 0 && !n.isBreak && (o = n.num), t.push(n && n.isBreak ? 0 : o)
                }
                return t
            }

            function N(e, t, o, r) {
                for (var n = r, a = Math.min(t + Math.max(o, 1) - 1, e.length - 1), l = t; l <= a; l++) e[l] > n && (n = e[l]);
                return Math.max(n - r + 1, 1)
            }

            function C(e) {
                for (var t = [], o = {}, r = e.querySelectorAll ? e.querySelectorAll("body *") : [], n = r.length > 8e3 ? 8e3 : r.length, a = 0; a < n; a++) {
                    var l = r[a];
                    if (!(l.children && l.children.length > 4)) {
                        var s = "";
                        try {
                            s = (l.innerText || l.textContent || "").replace(/\s+/g, " ").trim()
                        } catch (h) {
                            continue
                        }
                        if (s && !(s.length > 60)) {
                            var i = s.match(/^(?:上午|下午|晚上)?\s*第\s*(\d{1,2})\s*节/);
                            if (i) {
                                var c = parseInt(i[1], 10);
                                if (c >= 1 && c <= 15 && !o[c]) {
                                    var d = l.getBoundingClientRect ? l.getBoundingClientRect() : null;
                                    if (!(!d || d.height < 12 || d.width < 8)) {
                                        var u = s.match(/\d{1,2}:\d{2}/g) || [],
                                            m = null;
                                        try {
                                            m = V(l)
                                        } catch (h) {
                                            m = null
                                        }
                                        o[c] = !0, t.push({
                                            num: c,
                                            top: d.top,
                                            height: d.height,
                                            rowExact: Boolean(m),
                                            rowTop: m ? m.top : d.top,
                                            rowBottom: m ? m.bottom : d.top + d.height,
                                            start: u.length >= 2 ? u[0] : "",
                                            end: u.length >= 2 ? u[u.length - 1] : ""
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
                return t.sort((function(e, t) {
                    return e.top - t.top
                })), t
            }

            function V(e) {
                if (!e || !e.getBoundingClientRect) return null;
                for (var t = e.getBoundingClientRect(), o = e, r = 0; r < 5 && o; r++) {
                    if ("TR" === o.tagName && o.getBoundingClientRect) {
                        var n = o.getBoundingClientRect();
                        if (n.height > t.height + 6) return n
                    }
                    o = o.parentElement
                }
                o = e.parentElement;
                for (var a = 0; a < 3 && o; a++) {
                    var l = o.getBoundingClientRect ? o.getBoundingClientRect() : null;
                    if (l && l.height > t.height + 18 && l.height < 460) return l;
                    o = o.parentElement
                }
                return null
            }

            function T(e) {
                var t = [];
                if (!e || !e.length) return t;
                for (var o = !0, r = [], n = 0; n < e.length; n++) {
                    if (!e[n].rowExact) {
                        o = !1;
                        break
                    }
                    var a = e[n].rowBottom - e[n].rowTop;
                    if (!(a > 12)) {
                        o = !1;
                        break
                    }
                    r.push(a)
                }
                var l = 0;
                if (r.length && (r.sort((function(e, t) {
                        return e - t
                    })), l = r[Math.floor(r.length / 2)] || 0), o)
                    for (var s = Math.max(1.7 * l, 190), i = 1; i < e.length; i++) {
                        var c = e[i].rowTop - e[i - 1].rowBottom;
                        if (c < -12 || c > s) {
                            o = !1;
                            break
                        }
                    }
                if (o) {
                    for (var d = 0; d < e.length; d++) t.push({
                        num: e[d].num,
                        start: e[d].start,
                        end: e[d].end,
                        top: e[d].rowTop,
                        bottom: e[d].rowBottom
                    });
                    return t
                }
                for (var u = [], m = 0; m < e.length; m++) u.push(e[m].top + e[m].height / 2);
                var h = 60;
                if (e.length > 1) {
                    for (var p = [], y = 1; y < u.length; y++) p.push(u[y] - u[y - 1]);
                    p.sort((function(e, t) {
                        return e - t
                    })), h = p[Math.floor(p.length / 2)] || 60
                }
                for (var g = 0; g < e.length; g++) {
                    var f = g > 0 ? u[g - 1] : u[g] - h,
                        v = g < e.length - 1 ? u[g + 1] : u[g] + h;
                    t.push({
                        num: e[g].num,
                        start: e[g].start,
                        end: e[g].end,
                        top: (f + u[g]) / 2,
                        bottom: (u[g] + v) / 2
                    })
                }
                return t
            }

            function B(e, t) {
                if (!e || !t || !t.length || e.height < 8) return null;
                var o, r = e.top + 8,
                    n = null;
                for (o = 0; o < t.length; o++)
                    if (r >= t[o].top && r < t[o].bottom) {
                        n = t[o];
                        break
                    } if (!n)
                    for (o = 0; o < t.length; o++) t[o].top <= r && (!n || t[o].top > n.top) && (n = t[o]);
                if (!n) return null;
                var a = n,
                    l = 0,
                    s = Math.max(16, .18 * e.height);
                for (o = 0; o < t.length; o++)
                    if (!(t[o].num < n.num)) {
                        if (t[o].top >= e.bottom - s) break;
                        l++, a = t[o]
                    } return {
                    start: n.num,
                    span: Math.max(l, 1),
                    startTime: n.start || "",
                    endTime: a && a.end || n.end || ""
                }
            }

            function D(e) {
                for (var t = [], o = {}, r = e && e.querySelectorAll ? e.querySelectorAll("body *") : [], n = r.length > 8e3 ? 8e3 : r.length, a = 0; a < n; a++) {
                    var l = r[a];
                    if (!(l.children && l.children.length > 2)) {
                        var s = "";
                        try {
                            s = (l.innerText || l.textContent || "").replace(/\s+/g, " ").trim()
                        } catch (m) {
                            continue
                        }
                        if (s && !(s.length > 40)) {
                            var i = s.match(/^第\s*(\d{1,2})\s*节/);
                            if (i) {
                                var c = parseInt(i[1], 10);
                                if (!(c < 1 || c > 15 || o[c])) {
                                    var d = s.match(/\d{1,2}:\d{2}/g) || [];
                                    if (!(d.length < 2)) {
                                        var u = l.getBoundingClientRect ? l.getBoundingClientRect() : null;
                                        !u || u.height < 20 || u.width < 10 || (o[c] = !0, t.push({
                                            num: c,
                                            start: d[0],
                                            end: d[d.length - 1]
                                        }))
                                    }
                                }
                            }
                        }
                    }
                }
                return t.sort((function(e, t) {
                    return e.num - t.num
                })), t
            }

            function z(e, t) {
                if (!e || !e.length) return null;
                for (var o = 0; o < e.length; o++)
                    if (Number(e[o].num) === Number(t)) return e[o];
                return null
            }

            function M(e) {
                for (var t = [], o = e.querySelectorAll ? e.querySelectorAll("body *") : [], r = o.length > 9e3 ? 9e3 : o.length, n = 0; n < r; n++) {
                    var a = o[n];
                    if (a.getBoundingClientRect && !(a.children && a.children.length > 8)) {
                        var l = "";
                        try {
                            l = (a.innerText || a.textContent || "").replace(/\s+/g, " ").trim()
                        } catch (i) {
                            continue
                        }
                        if (!(l.length < 4 || l.length > 320)) {
                            var s = a.getBoundingClientRect();
                            !s || s.width < 40 || s.height < 24 || s.width > 460 || s.height > 620 || t.push({
                                text: l,
                                top: s.top,
                                bottom: s.bottom,
                                left: s.left,
                                right: s.right,
                                len: l.length
                            })
                        }
                    }
                }
                return t
            }

            function A(e) {
                for (var t = [], o = {}, r = e.querySelectorAll ? e.querySelectorAll("body *") : [], n = r.length > 6e3 ? 6e3 : r.length, a = 0; a < n; a++) {
                    var l = r[a],
                        s = "";
                    try {
                        s = (l.innerText || l.textContent || "").replace(/\s+/g, "").trim()
                    } catch (d) {
                        continue
                    }
                    if (/^(星期|周)[一二三四五六日天]$/.test(s)) {
                        var i = l.getBoundingClientRect ? l.getBoundingClientRect() : null;
                        if (!(!i || i.height < 10 || i.height > 70 || i.width < 8)) {
                            var c = "一二三四五六日".indexOf(s.charAt(s.length - 1)) + 1;
                            c && !o[c] && (o[c] = !0, t.push({
                                day: c,
                                cx: i.left + i.width / 2
                            }))
                        }
                    }
                }
                return t.sort((function(e, t) {
                    return e.cx - t.cx
                })), t
            }

            function I(e, t) {
                for (var o = 0; o < e.length; o++)
                    if (Number(e[o].num) === Number(t)) return e[o];
                return null
            }

            function _(e, t, o, r, n, a, l, s, i, c, d) {
                for (var u = null, m = 1e9, h = 0; h < e.length; h++)
                    if (!t[h]) {
                        var p = e[h];
                        if (!(p.top < i || p.bottom > c || p.text.indexOf(n) < 0)) {
                            var y = p.text.replace(/\s+/g, ""),
                                g = Boolean(a && y.indexOf(a) >= 0 || l && y.indexOf(l) >= 0);
                            if (!d || g) {
                                if (o.length >= 7) {
                                    for (var f = (p.left + p.right) / 2, v = 0, w = 1e9, b = 0; b < o.length; b++) {
                                        var S = Math.abs(o[b].cx - f);
                                        S < w && (w = S, v = o[b].day)
                                    }
                                    if (v && v !== Number(r.d)) continue
                                }
                                var k = B({
                                    top: p.top,
                                    bottom: p.bottom,
                                    height: p.bottom - p.top
                                }, s);
                                if (k) {
                                    var x = Math.abs(Number(k.start) - Number(r.s || 0)),
                                        E = !!u && p.len < e[u.idx].len;
                                    (x < m || x === m && E) && (u = {
                                        idx: h,
                                        hit: k,
                                        anchored: g
                                    }, m = x)
                                }
                            }
                        }
                    } return u
            }

            function P(e) {
                for (var o = [], r = 0; r < e.length; r++) {
                    var n = e[r],
                        l = "",
                        s = "";
                    try {
                        l = n.location ? n.location.href : ""
                    } catch (i) {}
                    try {
                        s = n.body && n.body.innerText ? n.body.innerText.replace(/\s+/g, " ").trim().slice(0, 160) : ""
                    } catch (i) {}
                    o.push({
                        idx: r,
                        url: a(l).slice(0, 120),
                        tables: n.querySelectorAll ? n.querySelectorAll("table").length : 0,
                        text: a(s)
                    })
                }
                return {
                    url: a(location.href),
                    docCount: e.length,
                    apiLogs: t,
                    frames: o
                }
            }
            var F = [];
            ! function e(t, o) {
                try {
                    t && t.document && o.push(t.document);
                    for (var r = t.frames || [], n = 0; n < r.length; n++) e(r[n], o)
                } catch (a) {}
            }(window, F);
            for (var R = function(e) {
                    for (var t = e.length - 1; t >= 0; t--) {
                        var o = "";
                        try {
                            o = e[t].body && e[t].body.innerText || ""
                        } catch (m) {
                            continue
                        }
                        if (o) {
                            var r = o.match(/第\s*(\d{1,2})\s*周\s*[（(]\s*(\d{1,2})\s*[\/\-.月]\s*(\d{1,2})/);
                            if (r) {
                                var n = parseInt(r[1], 10),
                                    a = parseInt(r[2], 10),
                                    l = parseInt(r[3], 10);
                                if (n >= 1 && n <= 30 && a >= 1 && a <= 12 && l >= 1 && l <= 31) {
                                    var s = new Date,
                                        i = s.getFullYear(),
                                        c = new Date(i, a - 1, l);
                                    a - (s.getMonth() + 1) > 6 && (c = new Date(i - 1, a - 1, l)), s.getMonth() + 1 - a > 6 && (c = new Date(i + 1, a - 1, l));
                                    var d = new Date(c.getTime() - 7 * (n - 1) * 864e5),
                                        u = function(e) {
                                            return e < 10 ? "0" + e : String(e)
                                        };
                                    return d.getFullYear() + "-" + u(d.getMonth() + 1) + "-" + u(d.getDate())
                                }
                            }
                        }
                    }
                    return ""
                }(F), L = [], W = 0; W < F.length; W++) {
                var U = D(F[W]);
                U.length > L.length && (L = U)
            }
            L.length || (L = D(document));
            var j, O = location.origin || location.protocol + "//" + location.host;

            function q() {
                var e = function(e) {
                    for (var t = e.length - 1; t >= 0; t--) {
                        var o = e[t],
                            r = [],
                            n = C(o),
                            a = T(n),
                            i = D(o);
                        n.length;
                        var c = o.querySelectorAll(".mtt_arrange_item");
                        if (c && c.length > 0) {
                            for (var d = 0; d < c.length; d++) {
                                var m = c[d],
                                    g = m.closest ? m.closest("td") : null,
                                    f = m.closest ? m.closest("table") : null,
                                    w = f ? E(f) : [],
                                    b = g && g.parentElement ? g.parentElement : null,
                                    S = b ? b.rowIndex : -1,
                                    k = 1,
                                    x = 0,
                                    V = 2;
                                if (g) {
                                    var M = g.getAttribute("data-day") || g.getAttribute("data-week") || "";
                                    k = M ? parseInt(M, 10) || 1 : g.cellIndex >= 1 ? Math.min(g.cellIndex, 7) : 1;
                                    var A = parseInt(g.getAttribute("data-unit"), 10);
                                    A >= 1 && A <= 12 && (x = A), !x && S >= 0 && w[S] && (x = w[S]);
                                    for (var I = parseInt(g.getAttribute("rowspan"), 10) || 1, _ = !1, P = 0; P < w.length; P++)
                                        if (w[P] > 0) {
                                            _ = !0;
                                            break
                                        } if (V = _ ? N(w, S, I, x) : Math.max(I, 1), !x && S >= 0) {
                                        var F = f && f.rows ? f.rows.length : 0;
                                        x = F >= 13 ? v(F >= 14 ? S : S + 1) : Math.max(S, 1)
                                    }
                                }
                                var R = B(m.getBoundingClientRect ? m.getBoundingClientRect() : null, a);
                                R && (x = R.start, V = R.span);
                                var L = (m.innerText || m.textContent || "").trim(),
                                    W = h(L);
                                W && (x = W.start, V = W.span);
                                var U = z(i, x),
                                    j = z(i, x + Math.max(V, 1) - 1),
                                    O = {
                                        start: R && R.startTime || (U ? U.start : ""),
                                        end: R && R.endTime || (j ? j.end : U ? U.end : "")
                                    },
                                    q = m.querySelector(".mtt_item_kcmc"),
                                    $ = m.querySelector(".mtt_item_jxbmc, .mtt_item_teacher"),
                                    H = m.querySelector(".mtt_item_room"),
                                    J = l(L),
                                    K = q ? (q.innerText || "").trim() : J[0] || "",
                                    G = $ ? ($.innerText || "").trim() : J[1] || "",
                                    X = H ? (H.innerText || "").trim() : "";
                                if (!X) {
                                    for (var Y = 1; Y < J.length; Y++)
                                        if (s(J[Y])) {
                                            X = J[Y];
                                            break
                                        }! X && J.length >= 3 && (X = J[2])
                                }
                                var Q = u(L);
                                K && r.push(p(K, G, X, k, x, V, Q, O))
                            }
                            if (r.length > 0) return y(r)
                        }
                    }
                    return []
                }(F);
                e.length > 0 ? n({
                    ok: !0,
                    src: "dom",
                    list: e,
                    semStart: R,
                    periods: L
                }) : n({
                    ok: !0,
                    src: "none",
                    list: [],
                    semStart: R,
                    periods: L,
                    diag: P(F)
                })
            }
            location.pathname.indexOf("/jwapp") >= 0 || location.href.indexOf("jwapp") >= 0 ? (j = function(e) {
                var a = [{
                    tag: "wdkb_xskcb",
                    method: "POST",
                    url: O + "/jwapp/sys/wdkb/modules/xskcb/xskcb.do",
                    body: "XNXQDM=" + encodeURIComponent(e)
                }, {
                    tag: "homeapp_post",
                    method: "POST",
                    url: O + "/jwapp/sys/homeapp/api/home/student/getMyScheduleDetail.do",
                    body: "termCode=" + encodeURIComponent(e) + "&type=term"
                }, {
                    tag: "homeapp_get",
                    method: "GET",
                    url: O + "/jwapp/sys/homeapp/api/home/student/getMyScheduleDetail.do?termCode=" + encodeURIComponent(e) + "&type=term",
                    body: null
                }, {
                    tag: "wdkb_zhxq",
                    method: "POST",
                    url: O + "/jwapp/sys/wdkb/modules/xskcb/cxxszhxqkb.do",
                    body: "XNXQDM=" + encodeURIComponent(e)
                }];
                ! function l(s) {
                    if (s >= a.length) q();
                    else {
                        var i = a[s];
                        S(i.method, i.url, i.body, (function(a, c) {
                            var d = b(k(c), L);
                            d = function(e, t) {
                                if (!(e && e.length && t && t.length)) return e;
                                for (var o = t.length - 1; o >= 0; o--) {
                                    var r = t[o],
                                        n = C(r);
                                    if (!(n.length < 6)) {
                                        var a = T(n);
                                        if (a.length) {
                                            var l = M(r);
                                            if (l.length) {
                                                for (var s = A(r), i = a[0].top - 30, c = a[a.length - 1].bottom + 30, d = {}, u = 0, m = 0; m < e.length; m++) {
                                                    var h = e[m],
                                                        p = String(h.n || "").replace(/\s+/g, "").slice(0, 6);
                                                    if (!(p.length < 2)) {
                                                        var y = "";
                                                        if (h.r) {
                                                            var g = String(h.r).split(/[;,，；\/]/)[0].replace(/\s+/g, "").trim(),
                                                                f = g.replace(/[^\d]/g, "");
                                                            if (f.length >= 3) y = f.slice(-4);
                                                            else {
                                                                var v = g.replace(/[^\u4e00-\u9fa5]/g, "");
                                                                v.length >= 2 && (y = v.slice(0, 3))
                                                            }
                                                        }
                                                        var w = "";
                                                        if (h.t) {
                                                            var b = String(h.t).replace(/[^\u4e00-\u9fa5]/g, "");
                                                            b.length >= 2 && (w = b.slice(0, 2))
                                                        }
                                                        var S = _(l, d, s, h, p, y, w, a, i, c, !0),
                                                            k = Boolean(S && S.anchored);
                                                        if (S || (S = _(l, d, s, h, p, y, w, a, i, c, !1), k = !1), S) {
                                                            d[S.idx] = !0, u++;
                                                            var x = S.hit;
                                                            x.start !== Number(h.s) && (h.s = x.start);
                                                            var E = x.span;
                                                            k && E > Number(h.p) && E <= Number(h.p) + 2 && (h.p = E);
                                                            var N = I(a, h.s),
                                                                V = I(a, Number(h.s) + Number(h.p) - 1) || N;
                                                            N && N.start && (h.st = N.start), V && V.end && (h.et = V.end)
                                                        }
                                                    }
                                                }
                                                if (u >= 2) return e
                                            }
                                        }
                                    }
                                }
                                return e
                            }(d, F), t.push(i.tag + ":" + a + ":n=" + d.length), d.length > 0 ? n({
                                ok: !0,
                                src: i.tag,
                                term: e,
                                semStart: r || R,
                                periods: L,
                                list: d,
                                skipped: capSkips,
                                sample: o
                            }) : l(s + 1)
                        }))
                    }
                }(0)
            }, S("GET", O + "/jwapp/sys/homeapp/api/home/currentUser.do", null, (function(e, o) {
                var n = k(o),
                    a = "";
                if (n && n.datas) {
                    a = n.datas.termCode || n.datas.xnxqdm || n.datas.welcomeInfo && (n.datas.welcomeInfo.xnxqdm || n.datas.welcomeInfo.termCode) || "";
                    var l = n.datas.weekOfTerm || n.datas.welcomeInfo && (n.datas.welcomeInfo.weekOfTerm || n.datas.welcomeInfo.dqz),
                        s = parseInt(l, 10);
                    if (s >= 1 && s <= 25) {
                        var i = new Date,
                            c = 0 === i.getDay() ? 7 : i.getDay(),
                            d = new Date(i.getFullYear(), i.getMonth(), i.getDate() - (c - 1)),
                            u = new Date(d.getTime() - 7 * (s - 1) * 864e5),
                            m = function(e) {
                                return e < 10 ? "0" + e : String(e)
                            };
                        r = u.getFullYear() + "-" + m(u.getMonth() + 1) + "-" + m(u.getDate())
                    }
                }
                t.push("u1:" + e + ":" + (a || "none")), a ? j(a) : S("POST", O + "/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do", "", (function(e, o) {
                    var r = k(o),
                        n = "";
                    if (r && r.datas && r.datas.dqxnxq && r.datas.dqxnxq.rows && r.datas.dqxnxq.rows[0] && (n = r.datas.dqxnxq.rows[0].DM || ""), t.push("u2:" + e + ":" + (n || "none")), n) j(n);
                    else {
                        var a = new Date,
                            l = a.getFullYear(),
                            s = a.getMonth() + 1 >= 8 ? l + "-" + (l + 1) + "-1" : l - 1 + "-" + l + "-2";
                        t.push("u3:guess:" + s), j(s)
                    }
                }))
            }))) : q()
        }

