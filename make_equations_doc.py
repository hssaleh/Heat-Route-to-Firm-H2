# -*- coding: utf-8 -*-
"""
make_equations_doc.py
Generate a Word (.docx) document containing every mathematical formula used in
the "Heat Route to Firm Green Hydrogen" model and analysis, as NATIVE Word
equation-editor objects (OMML), each followed by a discussion paragraph.

Approach: a small, brace-delimited mini-LaTeX -> OMML converter builds proper
stacked fractions, sub/superscripts, radicals, n-ary sums/integrals and accents
(the programmatic Word COM BuildUp cannot stack fractions). The document is
packed into a valid container reusing the namespaces from a Word-created
skeleton (skeleton.docx).

Author : generated for Prof. H. S. S. AbdelMeguid
"""
import os, re, zipfile, shutil, html

# -------------------------------------------------------------------------
# Mini-LaTeX -> OMML converter
# -------------------------------------------------------------------------
SYM = {
 'alpha':'α','beta':'β','gamma':'γ','delta':'δ','Delta':'Δ',
 'epsilon':'ε','varepsilon':'ε','zeta':'ζ','eta':'η','theta':'θ',
 'kappa':'κ','lambda':'λ','mu':'μ','nu':'ν','xi':'ξ','pi':'π',
 'rho':'ρ','sigma':'σ','Sigma':'Σ','tau':'τ','phi':'φ','Phi':'Φ',
 'psi':'ψ','Psi':'Ψ','omega':'ω','Omega':'Ω','chi':'χ',
 'cdot':'·','times':'×','approx':'≈','geq':'≥','leq':'≤',
 'pm':'±','infty':'∞','partial':'∂','rightarrow':'→','to':'→',
 'propto':'∝','neq':'≠','degree':'°','circ':'∘','ll':'≪','gg':'≫'
}
NARY = {'sum':'∑','int':'∫','prod':'∏','oint':'∮'}

def esc(t):
    return (t.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;'))

def run(t):
    if t=='':
        return ''
    return '<m:r><m:t xml:space="preserve">%s</m:t></m:r>' % esc(t)

def e(x):   return '<m:e>%s</m:e>' % x

def frac(n,d):
    return '<m:f><m:num>%s</m:num><m:den>%s</m:den></m:f>' % (n,d)
def ssup(b,s): return '<m:sSup><m:e>%s</m:e><m:sup>%s</m:sup></m:sSup>' % (b,s)
def ssub(b,s): return '<m:sSub><m:e>%s</m:e><m:sub>%s</m:sub></m:sSub>' % (b,s)
def ssubsup(b,sb,sp):
    return '<m:sSubSup><m:e>%s</m:e><m:sub>%s</m:sub><m:sup>%s</m:sup></m:sSubSup>'%(b,sb,sp)
def rad(x,deg=None):
    if deg is None:
        return '<m:rad><m:radPr><m:degHide m:val="1"/></m:radPr><m:deg/><m:e>%s</m:e></m:rad>'%x
    return '<m:rad><m:deg>%s</m:deg><m:e>%s</m:e></m:rad>'%(deg,x)
def nary(ch,lo,hi,body):
    sub = '<m:sub>%s</m:sub>'%lo if lo else '<m:sub/>'
    sup = '<m:sup>%s</m:sup>'%hi if hi else '<m:sup/>'
    return ('<m:nary><m:naryPr><m:chr m:val="%s"/><m:limLoc m:val="undOvr"/>'
            '<m:grow m:val="1"/></m:naryPr>%s%s<m:e>%s</m:e></m:nary>'%(ch,sub,sup,body))
def delim(x):
    return '<m:d><m:e>%s</m:e></m:d>'%x
def acc(ch,x):
    return '<m:acc><m:accPr><m:chr m:val="%s"/></m:accPr><m:e>%s</m:e></m:acc>'%(ch,x)
def bar(x):
    return '<m:bar><m:barPr><m:pos m:val="top"/></m:barPr><m:e>%s</m:e></m:bar>'%x

def read_group(s,i):
    """s[i]=='{' -> return (inner, index after matching '}')."""
    assert s[i]=='{'
    depth=0; j=i
    while j<len(s):
        if s[j]=='{': depth+=1
        elif s[j]=='}':
            depth-=1
            if depth==0: return s[i+1:j], j+1
        j+=1
    return s[i+1:], len(s)

def read_arg(s,i):
    """Read a script/command argument: a {group} or a single token/command."""
    if i<len(s) and s[i]=='{':
        inner,j=read_group(s,i); return conv(inner), j
    if i<len(s) and s[i]=='\\':
        m=re.match(r'\\([A-Za-z]+)',s[i:]); name=m.group(1); j=i+1+len(name)
        return conv('\\'+name), j
    if i<len(s):
        return run(s[i]), i+1
    return '', i

def conv(s):
    atoms=[]    # list of omml element strings
    buf=''      # pending plain-text run
    def flush():
        nonlocal buf
        if buf!='':
            atoms.append(run(buf)); buf=''
    i=0
    while i<len(s):
        c=s[i]
        if c=='\\':
            m=re.match(r'\\([A-Za-z]+)',s[i:])
            if not m:                       # escaped symbol like \{ or \,
                buf+=s[i+1] if i+1<len(s) else ''; i+=2; continue
            name=m.group(1); i+=1+len(name)
            if name=='frac':
                flush(); A,i=read_arg(s,i); B,i=read_arg(s,i); atoms.append(frac(A,B))
            elif name=='sqrt':
                flush()
                deg=None
                if i<len(s) and s[i]=='[':
                    k=s.index(']',i); deg=conv(s[i+1:k]); i=k+1
                A,i=read_arg(s,i); atoms.append(rad(A,deg))
            elif name in ('dot','bar','overline','hat','vec'):
                flush(); A,i=read_arg(s,i)
                if name=='dot': atoms.append(acc('̇',A))
                elif name in ('bar','overline'): atoms.append(bar(A))
                elif name=='hat': atoms.append(acc('̂',A))
                else: atoms.append(acc('⃗',A))
            elif name in ('text','mathrm','mathit','operatorname'):
                flush();
                if i<len(s) and s[i]=='{':
                    inner,i=read_group(s,i); atoms.append(run(inner))
            elif name in NARY:
                flush(); lo=''; hi=''
                while i<len(s) and s[i] in '_^':
                    op=s[i]; i+=1; arg,i=read_arg(s,i)
                    if op=='_': lo=arg
                    else: hi=arg
                body,i=read_arg(s,i)
                atoms.append(nary(NARY[name],lo,hi,body))
            elif name in SYM:
                flush(); buf+=SYM[name]; flush()
            elif name=='left' or name=='right':
                pass                          # delimiters handled as literal ( )
            elif name=='quad':
                flush(); buf+='   '; flush()
            else:
                flush(); buf+=name; flush()    # unknown -> literal
        elif c=='{':
            inner,i=read_group(s,i);
            flush(); atoms.append(conv(inner))
        elif c=='^' or c=='_':
            i+=1; arg,i=read_arg(s,i)
            # base = last atom (split trailing char of a plain run for tight binding)
            if buf!='':
                base=run(buf[-1]); pre=buf[:-1]; buf=''
                if pre: atoms.append(run(pre))
            elif atoms:
                base=atoms.pop()
            else:
                base=run('')
            # combine, allowing x_a^b / x^a_b
            if c=='^':
                if base.startswith('<m:sSub>'):     # already has sub -> subsup
                    inner=base[len('<m:sSub>'):-len('</m:sSub>')]
                    bb=re.search(r'<m:e>(.*)</m:e><m:sub>(.*)</m:sub>',inner,re.S)
                    atoms.append(ssubsup(bb.group(1),bb.group(2),arg))
                else:
                    atoms.append(ssup(base,arg))
            else:
                if base.startswith('<m:sSup>'):
                    inner=base[len('<m:sSup>'):-len('</m:sSup>')]
                    bb=re.search(r'<m:e>(.*)</m:e><m:sup>(.*)</m:sup>',inner,re.S)
                    atoms.append(ssubsup(bb.group(1),arg,bb.group(2)))
                else:
                    atoms.append(ssub(base,arg))
        else:
            buf+=c; i+=1
    flush()
    return ''.join(atoms)

def omath(latex):
    return '<m:oMath>%s</m:oMath>' % conv(latex)

# -------------------------------------------------------------------------
# Word paragraph builders
# -------------------------------------------------------------------------
def p_text(text, style=None, bold=False, size=None, align=None):
    ppr=''
    inner=''
    if style: ppr+='<w:pStyle w:val="%s"/>'%style
    if align: ppr+='<w:jc w:val="%s"/>'%align
    rpr=''
    if bold: rpr+='<w:b/>'
    if size: rpr+='<w:sz w:val="%d"/><w:szCs w:val="%d"/>'%(size,size)
    rpr_el = '<w:rPr>%s</w:rPr>'%rpr if rpr else ''
    runs=''
    for line in text.split('\n'):
        runs+='<w:r>%s<w:t xml:space="preserve">%s</w:t></w:r>'%(rpr_el,esc(line))
    return '<w:p><w:pPr>%s%s</w:pPr>%s</w:p>'%(ppr, ('<w:rPr>%s</w:rPr>'%rpr if rpr else ''), runs)

def p_heading(text, level=1):
    sz = {1:34,2:28,3:24}.get(level,24)
    return ('<w:p><w:pPr><w:pStyle w:val="Heading%d"/><w:spacing w:before="240" w:after="120"/>'
            '<w:rPr><w:b/><w:color w:val="1F3864"/><w:sz w:val="%d"/></w:rPr></w:pPr>'
            '<w:r><w:rPr><w:b/><w:color w:val="1F3864"/><w:sz w:val="%d"/></w:rPr>'
            '<w:t xml:space="preserve">%s</w:t></w:r></w:p>'%(level,sz,sz,esc(text)))

def p_equation(latex, number=None):
    # centered equation with a right-aligned equation number using tab stops
    tabs=('<w:tabs><w:tab w:val="center" w:pos="4680"/><w:tab w:val="right" w:pos="9360"/></w:tabs>')
    num = ''
    if number:
        num = '<w:r><w:tab/><w:t xml:space="preserve">(%s)</w:t></w:r>'%esc(str(number))
    return ('<w:p><w:pPr>%s<w:spacing w:before="80" w:after="80"/></w:pPr>'
            '<w:r><w:tab/></w:r><m:oMathPara><m:oMathParaPr>'
            '<m:jc m:val="center"/></m:oMathParaPr>%s</m:oMathPara>%s</w:p>'
            % (tabs, omath(latex), num))

def p_disc(text):
    return ('<w:p><w:pPr><w:spacing w:after="160"/><w:ind w:left="180"/>'
            '<w:rPr><w:sz w:val="21"/></w:rPr></w:pPr>'
            '<w:r><w:rPr><w:sz w:val="21"/></w:rPr>'
            '<w:t xml:space="preserve">%s</w:t></w:r></w:p>'%esc(text))

# =========================================================================
# DOCUMENT CONTENT - sections, equations (mini-LaTeX), discussions
# =========================================================================
BODY=[]
def H1(t): BODY.append(p_heading(t,1))
def H2(t): BODY.append(p_heading(t,2))
def PARA(t): BODY.append(p_text(t, size=21))
def EQ(latex, num, disc): BODY.append(p_equation(latex,num)); BODY.append(p_disc(disc))

# ---- Title block --------------------------------------------------------
BODY.append(p_text('Mathematical Formulation - The Heat Route to Firm Green Hydrogen',
                   bold=True, size=36, align='center'))
BODY.append(p_text('Complete set of governing, thermodynamic, exergetic, economic, '
                   'environmental and dimensionless equations, with discussion',
                   size=24, align='center'))
BODY.append(p_text('Companion to the MATLAB implementation (HeatRouteFirmH2). '
                   'Prepared for Prof. H. S. S. AbdelMeguid.', size=20, align='center'))

H1('1. Hydrogen Thermodynamics and Reference Voltages')
EQ(r'V_{rev}^{0}=\frac{\Delta G^{0}}{z\cdot F}=\frac{237200}{2\cdot 96485}=1.229\ \text{V}', 1,
   'Reversible cell voltage: the minimum electrical work per unit charge to split water at standard conditions, set by the Gibbs free energy of reaction. It is the thermodynamic floor of the electrolysis voltage.')
EQ(r'V_{tn}^{0}=\frac{\Delta H^{0}}{z\cdot F}=\frac{285800}{2\cdot 96485}=1.481\ \text{V}', 2,
   'Thermoneutral voltage: the voltage at which the electrical input alone supplies the full reaction enthalpy. Operating below it leaves an enthalpy deficit that must be supplied as heat - the basis of the heat route.')

H1('2. Solar Geometry and Resource')
EQ(r'\delta=23.45^{\circ}\cdot\sin\left(360^{\circ}\frac{284+n}{365}\right)', 3,
   'Solar declination as a function of day of year n (Cooper). It fixes the seasonal solar path and, with latitude, the daily irradiation envelope used to synthesise the resource.')
EQ(r'\omega=15^{\circ}\cdot(t_{solar}-12)', 4,
   'Hour angle: the angular displacement of the sun from solar noon, 15 degrees per hour, locating the sun through the day.')
EQ(r'\cos\theta_{z}=\sin\delta\sin\phi+\cos\delta\cos\phi\cos\omega', 5,
   'Solar zenith angle from declination, latitude and hour angle - the master geometric relation governing beam incidence and air mass.')
EQ(r'\cos\theta=\sqrt{\cos^{2}\theta_{z}+\cos^{2}\delta\,\sin^{2}\omega}', 6,
   'Incidence angle on a horizontal N-S single-axis tracking parabolic-trough aperture; it determines the cosine and incidence-angle-modifier losses of the collector field.')
EQ(r'T_{cell}=T_{amb}+\frac{NOCT-20}{800}\,G', 7,
   'PV module temperature via the NOCT method; cell heating reduces PV output through the temperature coefficient.')
EQ(r'P_{PV}=C_{PV}\frac{G}{G_{stc}}\left[1-\gamma_{PV}(T_{cell}-25)\right]\eta_{PV,sys}', 8,
   'PV power from the temperature-corrected single-point model, scaled by installed DC capacity and the system performance ratio.')
EQ(r'P_{wind}=C_{wind}\frac{\rho}{\rho_{0}}\frac{v^{3}-v_{in}^{3}}{v_{r}^{3}-v_{in}^{3}},\quad v_{in}\leq v<v_{r}', 9,
   'Wind power in the cubic region of the normalized four-region power curve with air-density correction; flat at rated between v_r and v_out and zero outside the cut-in/cut-out band.')

H1('3. CSP Solar Field (Heat Route)')
EQ(r'K(\theta)=1-b_{1}\theta-b_{2}\theta^{2}', 12,
   'Incidence-angle modifier capturing the optical de-rating of the collector as the beam departs from normal incidence.')
EQ(r'\dot{Q}_{abs}=G_{b}\,A_{ap}\,\eta_{opt,0}\,K(\theta)\,f_{avail}\,f_{clean}', 13,
   'Absorbed beam power on the field aperture after optical efficiency, IAM, availability and mirror-cleanliness factors. This is the primary thermal harvest of the heat route.')
EQ(r'\dot{Q}_{loss}=A_{rec}\left[a_{0}+a_{1}(T_{htf}-T_{amb})+a_{2}(T_{htf}-T_{amb})^{2}\right]', 14,
   'Receiver thermal losses (convective and radiative) as a quadratic in the temperature difference between the heat-transfer fluid and ambient.')
EQ(r'\dot{Q}_{field}=\max\left(0,\ \dot{Q}_{abs}-\dot{Q}_{loss}\right)', 15,
   'Net useful field thermal output delivered to the power block and storage.')
EQ(r'SM=\frac{\dot{Q}_{field,design}}{\dot{Q}_{pb,in,design}}', 16,
   'Solar multiple: the field is oversized relative to the design block input so that surplus daytime heat can charge storage for round-the-clock firm operation.')

H1('4. Two-Tank Thermal Storage and Power Block')
EQ(r'E_{TES}(t)=E_{TES}(t-1)+\left[\eta_{ch}\dot{Q}_{ch}-\frac{\dot{Q}_{dis}}{\eta_{dis}}-\dot{Q}_{sb}\right]\Delta t', 17,
   'Energy balance of the molten-salt store with separate charge/discharge efficiencies and a standby loss; the diurnal charge-discharge cycle is what delivers firmness in the heat route.')
EQ(r'E_{TES,max}=h_{TES}\cdot\dot{Q}_{pb,in,design}', 18,
   'Storage capacity expressed through the storage duration in full-load hours - the key sizing lever for overnight firmness.')
EQ(r'P_{gross}=\eta_{pb}\,f_{pl}\,\dot{Q}_{pb,in};\qquad P_{net,A}=P_{gross}(1-f_{par})', 21,
   'Rankine gross electrical output from delivered thermal power with a part-load correction, less the parasitic fraction to obtain net electricity for the SOEC.')

H1('5. SOEC Electrochemical and Thermal Model')
EQ(r'V_{rev}(T)=\frac{\Delta G(T)}{z\cdot F}+\frac{R\,T}{z\cdot F}\ln\!\frac{p_{H_2}\,p_{O_2}^{0.5}}{p_{H_2O}}', 23,
   'Temperature-dependent Nernst voltage for steam electrolysis; at SOEC temperatures it falls to about 0.9 V, lowering the electrical demand.')
EQ(r'\eta_{act,k}=\frac{R\,T}{\alpha_{k}\,z\,F}\,\operatorname{asinh}\!\left(\frac{i}{2\,i_{0,k}}\right),\quad k\in\{an,cat\}', 24,
   'Activation overpotential per electrode from the symmetric Butler-Volmer kinetics written in inverse-hyperbolic-sine form.')
EQ(r'i_{0,k}=\gamma_{k}\exp\!\left(\frac{-E_{act,k}}{R\,T}\right)', 25,
   'Exchange current density with an Arrhenius temperature dependence; higher temperature raises kinetics and lowers activation losses.')
EQ(r'\eta_{ohm}=i\cdot ASR_{ohm}(T);\qquad ASR_{ohm}=\frac{\delta_{el}}{\sigma_{el}(T)}', 26,
   'Ohmic overpotential from the area-specific resistance, dominated by the electrolyte thickness over its conductivity.')
EQ(r'\sigma_{el}(T)=\sigma_{0}\exp\!\left(\frac{-E_{\sigma}}{R\,T}\right)', 27,
   'Thermally-activated ionic conductivity of the YSZ electrolyte; the strong temperature rise is why SOECs operate near 1000 K.')
EQ(r'V_{cell}=V_{rev}(T)+\eta_{act,an}+\eta_{act,cat}+\eta_{ohm}+\eta_{conc}', 29,
   'Total operating cell voltage as the sum of reversible voltage and the activation, ohmic and concentration overpotentials.')
EQ(r'\dot{m}_{H_2}=\eta_{F}\,\frac{i\,A_{cell}\,N_{cells}}{z\,F}\,M_{H_2}', 31,
   'Hydrogen mass production from Faraday’s law scaled by the stack size and Faradaic efficiency.')
EQ(r'\dot{Q}_{rxn}=\max\!\left(0,\ i\,A_{cell}\,N_{cells}\,(V_{tn}(T)-V_{cell})\right)', 33,
   'Endothermic reaction heat demanded when the cell runs below thermoneutral; supplied by the CSP/TES system in the heat route.')
EQ(r'\dot{Q}_{steam}=\dot{n}_{H_2O}\left[c_{p,liq}(T_{boil}-T_{feed})+\Delta h_{vap}+c_{p,vap}(T_{SOEC}-T_{boil})\right]', 34,
   'Heat to raise feed water to superheated steam at the SOEC temperature - the second thermal draw met by solar heat.')
EQ(r'\eta_{SOEC,el}=\frac{V_{tn}(T)}{V_{cell}}', 36,
   'Electrical (voltage) efficiency of the SOEC; because part of the energy enters as heat it can exceed low-temperature values.')

H1('6. Battery and Low-Temperature Electrolyzer (Electricity Route)')
EQ(r'SOC(t)=SOC(t-1)+\left[\eta_{bc}P_{bc}-\frac{P_{bd}}{\eta_{bd}}\right]\frac{\Delta t}{E_{batt}}', 38,
   'Battery state-of-charge balance with charge/discharge efficiencies; the round-trip loss and high energy cost make electrical firming expensive.')
EQ(r'SEC(\ell)=SEC_{rated}\left[1+\kappa_{0}\left(\frac{1}{\ell}-1\right)\right]', 41,
   'Part-load specific energy consumption of the low-temperature electrolyzer rising at low load fraction.')
EQ(r'\dot{m}_{H_2,B}=\frac{P_{LT}}{SEC(\ell)}', 42,
   'Hydrogen output of the LT electrolyzer from its power input and load-dependent specific energy use.')

H1('7. Dispatch and the Firmness Constraint')
EQ(r'\dot{m}_{H_2}(t)\geq \dot{m}_{H_2,firm}\quad \forall t', 44,
   'The defining firmness constraint: a constant hydrogen output must be met every hour, which converts the electrolyzer into a constant load that storage must serve.')
EQ(r'\dot{m}_{H_2,firm}=CF_{firm}\cdot \bar{\dot{m}}_{H_2}', 45,
   'Firm output level set by the firm capacity factor times the rated production.')

H1('8. Techno-Economics and Levelized Cost of Hydrogen')
EQ(r'CAPEX=\sum_{j}c_{j}\,S_{j}', 51,
   'Total capital cost as the sum over components of unit cost times sized capacity.')
EQ(r'CRF=\frac{WACC\,(1+WACC)^{L}}{(1+WACC)^{L}-1}', 52,
   'Capital recovery factor annuitizing the capital over the project life at the weighted average cost of capital.')
EQ(r'C_{ann}=CRF\cdot CAPEX+OPEX_{fix}+OPEX_{var}+C_{water}+C_{repl,ann}', 54,
   'Total annualized cost: annuitized capital plus fixed and variable O&M, water and annualized stack replacement.')
EQ(r'LCOH=\frac{C_{ann}}{M_{H_2,ann}}', 56,
   'Levelized cost of hydrogen: the annualized cost divided by annual hydrogen delivered - the study’s headline metric (here on a firm-output basis).')
EQ(r'c_{j}=c_{j,ref}\left(\frac{Cap_{cum}}{Cap_{ref}}\right)^{-b_{j}},\quad b_{j}=-\log_{2}(1-LR_{j})', 57,
   'One-factor learning curve mapping cumulative deployment to unit cost via the learning rate, used for the 2030/2050 cost scenarios.')

H1('9. Exergy Attribution (Second Law)')
EQ(r'\dot{Ex}_{solar}=\dot{Q}_{abs}\left[1-\frac{4}{3}\frac{T_{0}}{T_{sun}}+\frac{1}{3}\left(\frac{T_{0}}{T_{sun}}\right)^{4}\right]', 58,
   'Exergy of concentrated solar radiation via the Petela efficiency; it quantifies the maximum work extractable from the solar input.')
EQ(r'\dot{Ex}_{H_2}=\dot{m}_{H_2}\,ex_{H_2}', 59,
   'Exergy carried by the hydrogen product through its specific chemical exergy.')
EQ(r'\psi=\frac{\sum_{t}\dot{Ex}_{H_2}(t)\,\Delta t}{\sum_{t}\dot{Ex}_{in}(t)\,\Delta t}', 60,
   'Overall (second-law) exergy efficiency: the share of input exergy preserved as chemical exergy of hydrogen.')
EQ(r'\dot{Ex}_{dest,c}=\dot{Ex}_{in,c}-\dot{Ex}_{out,c}', 61,
   'Component exergy destruction from a steady exergy balance; mapping it locates the dominant irreversibilities.')

H1('10. Optimization and Comparison Metrics')
EQ(r'\min_{x}\ LCOH(x)\quad \text{s.t.}\ \dot{m}_{H_2}(t)\geq\dot{m}_{H_2,firm},\ \forall t', 62,
   'Per-cell least-cost sizing problem subject to firmness and all physical balances; solved by a deterministic grid-plus-refine search over the decision vector.')
EQ(r'\Delta LCOH(g)=LCOH_{B}^{*}(g)-LCOH_{A}^{*}(g)', 67,
   'Cost-difference metric per grid cell; positive values mark where the heat route is the cheaper firm-hydrogen architecture.')
EQ(r'DNI^{*}:\ \Delta LCOH(DNI^{*})=0', 69,
   'Break-even direct-normal-irradiance: the crossover resource level at which the two routes cost the same - the transferable rule of thumb.')

H1('11. Uncertainty Propagation')
EQ(r'\Pr[\Delta LCOH(g)>0]=\frac{1}{M}\sum_{m=1}^{M}\mathbf{1}\!\left[\Delta LCOH_{m}(g)>0\right]', 71,
   'Monte-Carlo dominance probability: the fraction of Latin-hypercube draws in which the heat route wins, converting the central claim into a probabilistic statement.')

H1('12. Extended Analysis Equations (Implemented in the Code)')
PARA('The following relations extend the model document and are computed by the MATLAB pipeline for the deeper scientific analysis (efficiencies, entropy, environment and the innovative dimensionless groups).')
EQ(r'\eta_{I}=\frac{\dot{m}_{H_2}\,LHV_{H_2}}{E_{in}};\qquad \eta_{STH}=\frac{\dot{m}_{H_2}\,LHV_{H_2}}{G_{b}\,A_{ap}}', 'A1',
   'First-law conversion efficiency and overall solar-to-hydrogen efficiency, the energy counterparts of the exergy efficiency.')
EQ(r'\dot{S}_{gen,c}=\frac{\dot{Ex}_{dest,c}}{T_{0}}', 'A2',
   'Gouy-Stodola theorem linking exergy destruction to entropy generation; ranking components by entropy generation identifies the dominant irreversibilities.')
EQ(r'N_{s}=\frac{\sum_{c}\dot{Ex}_{dest,c}}{\dot{Ex}_{in}}', 'A3',
   'Entropy-generation number: the fraction of input exergy destroyed, a compact measure of overall thermodynamic imperfection.')
EQ(r'\Lambda=\frac{\dot{Q}_{SOEC,heat}}{P_{SOEC}+\dot{Q}_{SOEC,heat}}', 'A4',
   'Heat-leverage ratio: the fraction of the total splitting energy supplied as storable heat - the physical core of the heat-route advantage (zero for the electricity route).')
EQ(r'\sigma_{th}=\frac{\dot{Q}_{heat}+P_{block}}{P_{SOEC}+\dot{Q}_{heat}}', 'A5',
   'Storage-medium split: the thermal-path share of the energy delivered to the SOEC in the hybrid; its variation with DNI defines the firmness efficient frontier.')
EQ(r'\pi_{firm}=\frac{LCOH_{firm}-LCOH_{avg}}{LCOH_{avg}}', 'A6',
   'Firmness premium: the cost increment of imposing 24-hour firmness; it is large and positive for the battery route but near zero or negative for the heat route, the premium-reversal result.')
EQ(r'Re=\frac{\rho\,v\,D}{\mu},\quad Pr=\frac{\mu\,c_{p}}{k},\quad Nu=0.023\,Re^{0.8}Pr^{0.4}', 'A7',
   'Reynolds, Prandtl and Dittus-Boelter Nusselt numbers characterising forced convection of the molten-salt heat-transfer fluid in the receiver tubes.')
EQ(r'Ra=Gr\cdot Pr=\frac{g\,\beta\,(T_{htf}-T_{0})\,L_{c}^{3}}{\nu^{2}}\cdot Pr', 'A8',
   'Rayleigh number (product of Grashof and Prandtl) governing natural-convection receiver losses to the environment.')
EQ(r'Bi=\frac{h\,L_{c}}{k},\qquad Fo=\frac{\alpha\,t}{L_{c}^{2}}', 'A9',
   'Biot and Fourier numbers describing the transient thermal response of the storage tanks (thermally thin store, slow diurnal diffusion).')
EQ(r'Ja=\frac{c_{p}\,\Delta T_{sup}}{h_{fg}},\qquad Ste=\frac{c_{p}\,\Delta T_{sens}}{h_{fg}}', 'A10',
   'Jakob and Stefan numbers comparing sensible/superheat to latent heat in raising the SOEC feed steam.')
EQ(r'C_{CO_2}=\frac{LCOH-LCOH_{grey}}{CI_{SMR}},\qquad \dot{m}_{CO_2}=\dot{m}_{H_2}\,CI_{SMR}', 'A11',
   'CO2 abatement cost relative to grey (SMR) hydrogen and the avoided-emissions rate; the environmental and climate value of the green output.')

# =========================================================================
# Assemble document.xml from the Word skeleton and pack the .docx
# =========================================================================
HERE=os.path.dirname(os.path.abspath(__file__))
SKEL=os.path.join('C:\\','tmp','eqtest2.docx')      # valid Word-made container
OUT =os.path.join(HERE,'output','HeatRoute_FirmH2_Equations.docx')

work=os.path.join('C:\\','tmp','eqbuild')
if os.path.exists(work): shutil.rmtree(work)
os.makedirs(work)
with zipfile.ZipFile(SKEL) as z: z.extractall(work)

docxml=os.path.join(work,'word','document.xml')
with open(docxml,'r',encoding='utf-8') as f: xml=f.read()
head=xml[:xml.index('<w:body>')+len('<w:body>')]
# keep the final sectPr from the skeleton for valid page setup
m=re.search(r'(<w:sectPr[\s\S]*?</w:sectPr>)',xml)
sectpr=m.group(1) if m else ''
newbody = head + ''.join(BODY) + sectpr + '</w:body></w:document>'
with open(docxml,'w',encoding='utf-8') as f: f.write(newbody)

os.makedirs(os.path.join(HERE,'output'),exist_ok=True)
if os.path.exists(OUT): os.remove(OUT)
zf=zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED)
for root,_,files in os.walk(work):
    for fn in files:
        full=os.path.join(root,fn)
        arc=os.path.relpath(full,work)
        zf.write(full,arc)
zf.close()
print('Wrote',OUT)
print('Equations:', sum(1 for b in BODY if 'oMathPara' in b))
