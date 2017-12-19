package coconut.ui.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.Tools;
using tink.MacroApi;

class ViewBuilder {
  static function build() {
    return ClassBuilder.run([function (c:ClassBuilder) {
      
      function add(t:TypeDefinition) {
        for (f in t.fields)
          c.addMember(f);
        return t.fields;
      }

      if (!c.target.meta.has(':tink'))
        c.target.meta.add(':tink', [], c.target.pos);

      function scrape(name:String, ?aliases:Array<String>) {
        var ret = [];

        switch c.memberByName('${name}s') {
          case Success(group):
            var m = group.getVar(true).sure();

            if (m.expr != null) 
              m.expr.reject('initialization not allowed here');

            switch m.type {
              case TAnonymous(fields):
                for (f in fields) 
                  c.addMember(f).addMeta(':$name');
              default:
                group.pos.error('not implemented');
            }
            c.removeMember(group);
          default:
        }

        var tags = [name].concat(switch aliases {
          case null: [];
          case v: v;
        });

        for (m in c)
          for (t in tags)
            switch m.extractMeta(':$t') {
              case Success(_):
                if (m.kind.match(FProp(_, _, _, _)))
                  m.pos.error('$name cannot be property');
                ret.push(m);
              default:
            }

        return ret;
      }

      var defaultValues = [],
          defaults = '__DEFAULTS';

      c.addMember({
        name: defaults,
        meta: [{ name: ':nocompletion', params: [], pos: c.target.pos }],
        kind: FProp('default', 'never', null, EObjectDecl(defaultValues).at(c.target.pos)),
        access: [AStatic],
        pos: c.target.pos,
      });

      var slots = [],
          initSlots = [],
          slotFields = [];

      c.addMember({
        name: '__slots',
        meta: [{ name: ':nocompletion', params: [], pos: c.target.pos }],
        kind: FProp('default', 'never', TAnonymous(slotFields), EObjectDecl(slots).at(c.target.pos)),
        access: [],
        pos: c.target.pos,
      });

      var pseudoData = [],
          attributes = [];

      {
        var attributes = TAnonymous(attributes);
        if (c.hasConstructor())
          c.getConstructor().toHaxe().pos.error('custom constructor not allowed');
        c.getConstructor((macro @:pos(c.target.pos) function (data:$attributes) super(render)).getFunction().sure()).isPublic = false;

        var self = Context.getLocalType().toComplexType();
        var params = switch self {
          case TPath(t): t.params;
          default: throw 'assert';
        }
        c.addMembers(macro class {
          @:noCompletion static public function __init(attributes:$attributes, ?inst:$self):$self {
            if (inst == null)
              inst = ${c.target.name.instantiate([macro attributes], params)};
            $b{initSlots};
            return inst;
          }
          @:keep function toString() {
            return $v{c.target.name};
          }
        })[0].getFunction().sure().params = [for (p in c.target.params) {
          name: p.name,
          constraints: {
            switch p.t {
              case TInst(_.get() => { kind: KTypeParameter(constraints) }, _):
                [for (c in constraints) c.toComplex()];
              default: throw 'assert';
            }
          }
        }];
      }

      for (a in scrape('attribute', ['attr'])) {
        function add(type:ComplexType, expr:Expr) {
          var optional = expr != null,
              name = a.name;

          var data = macro @:pos(a.pos) attributes.$name;

          if (optional) {
            defaultValues.push({ field: a.name, expr: expr });//TODO: consider making this readonly
            data = macro @:pos(data.pos) $data.or($i{defaults}.$name);
            expr.typeof().sure();
          }

          initSlots.push(macro @:pos(a.pos) inst.__slots.$name.setData($data));

          slots.push({ field: a.name, expr: macro new coconut.ui.tools.Slot(this) });
          slotFields.push({
            name: a.name,
            pos: a.pos,
            kind: FVar(macro : coconut.ui.tools.Slot<$type>)
          });

          a.kind = FProp('get', 'never', type, null);
          a.isPublic = true;

          attributes.push({
            name: a.name,
            pos: a.pos,
            kind: FVar(macro : coconut.data.Value<$type>),
            meta: if (optional) [{ name: ':optional', params: [], pos: a.pos }] else [],
          });
          
          pseudoData.push(a);
          
          c.addMember(Member.getter(name, a.pos, macro return this.__slots.$name.value, type));
        }

        switch a.kind {
          case FVar(null, _):
            a.pos.error('type required');//TODO: infer if possible
          case FVar(t, e):
            add(t, e);
          case FFun(f):
            add(
              TFunction(
                [for (a in f.args) if (a.opt) TOptional(a.type) else a.type], //TODO: apparently how optional arguments are dealt with doesn't work properly
                switch f.ret {
                  case null: macro : Void;
                  case v: v;
                }
              ),//TODO: rewrite this to be Callback when suitable
              if (f.expr == null) null
              else f.asExpr(a.pos)
            );
          default: a.pos.error('not implemented'); 
        }
      }

      var renderer = switch c.memberByName('render') {
        case Success(m): 
          m.getFunction().sure();
        default:
          c.target.pos.error('missing field render');
      }

      switch renderer.args {
        case []:
        case [{ type: null, name: name}]:
          renderer.args = [];
          
          if (renderer.expr.getString().isSuccess())
            renderer.expr = macro return @hxx ${renderer.expr};//it's not particular nice to duplicate this logic with tink_lang

          renderer.expr = macro @:pos(renderer.expr.pos) {
            var $name = this;
            ${renderer.expr};
          }
        case [_]:
          c.memberByName('render').sure().pos.error('argument should not be specified');
        default:
      }

      for (s in scrape('state')) {
        var v = s.getVar(true).sure();
        if (v.expr == null)
          s.pos.error('@:state requires initial value');
        var t = v.type;
        var internal = '__coco_${s.name}',
            get = 'get_${s.name}',
            set = 'set_${s.name}';

        c.addMembers(macro class {
          @:noCompletion private var $internal:tink.state.State<$t> = new tink.state.State(${v.expr});
          inline function $get():$t return $i{internal}.value;
          inline function $set(param:$t) {
            $i{internal}.set(param);
            return param;
          }
        });
        s.kind = FProp('get', 'set', t, null);
      }

    }]);
  }
}
#end